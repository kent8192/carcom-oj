#!/usr/bin/env bash
set -euo pipefail

bin_path="${1:?usage: local-test.sh BIN TESTS_DIR TLE_SEC [ignored args...]}"
tests_dir="${2:?usage: local-test.sh BIN TESTS_DIR TLE_SEC [ignored args...]}"
tle_sec="${3:?usage: local-test.sh BIN TESTS_DIR TLE_SEC [ignored args...]}"
shift 3

if [ "$#" -gt 0 ]; then
    printf '[WARNING] local sample runner ignores extra oj args: %s\n' "$*" >&2
fi

now() {
    perl -MTime::HiRes=time -e 'printf "%.6f", time'
}

elapsed_since() {
    local started="$1"
    awk -v started="$started" -v ended="$(now)" 'BEGIN { printf "%.6f", ended - started }'
}

is_gt() {
    awk -v lhs="$1" -v rhs="$2" 'BEGIN { exit !(lhs > rhs) }'
}

print_case_input() {
    sed 's/ /_/g' "$1"
}

print_file_or_empty() {
    if [ -s "$1" ]; then
        cat "$1"
    else
        echo '(empty)'
    fi
}

mapfile -t input_files < <(find "$tests_dir" -maxdepth 1 -type f -name '*.in' | sort)
if [ "${#input_files[@]}" -eq 0 ]; then
    echo "[FAILURE] no input cases found: $tests_dir" >&2
    exit 1
fi

echo "[INFO] ${#input_files[@]} cases found"
echo

passed=0
slowest_time=0
slowest_case=""

for input_file in "${input_files[@]}"; do
    case_name="$(basename "${input_file%.in}")"
    expected_file="$tests_dir/$case_name.out"
    actual_file="$(mktemp)"
    stderr_file="$(mktemp)"
    status="FAILURE"
    reason=""
    rc=0

    echo "[INFO] $case_name"

    started="$(now)"
    "$bin_path" <"$input_file" >"$actual_file" 2>"$stderr_file" &
    pid="$!"

    timeout_file="$(mktemp)"
    timed_out=0
    (
        sleep "$tle_sec"
        if kill -0 "$pid" 2>/dev/null; then
            echo 1 >"$timeout_file"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 0.05
            kill -KILL "$pid" 2>/dev/null || true
        fi
    ) &
    watchdog_pid="$!"

    set +e
    wait "$pid" 2>/dev/null
    rc="$?"
    kill "$watchdog_pid" 2>/dev/null
    wait "$watchdog_pid" 2>/dev/null
    set -e

    if [ -s "$timeout_file" ]; then
        timed_out=1
    fi

    elapsed="$(elapsed_since "$started")"
    if is_gt "$elapsed" "$slowest_time"; then
        slowest_time="$elapsed"
        slowest_case="$case_name"
    fi

    if [ "$timed_out" -eq 1 ]; then
        reason="TLE"
    elif [ "$rc" -ne 0 ]; then
        reason="RE: return code $rc"
    elif [ ! -f "$expected_file" ]; then
        reason="missing expected output"
    elif diff -q <(sed 's/\r$//' "$actual_file") <(sed 's/\r$//' "$expected_file") >/dev/null; then
        status="SUCCESS"
        reason="AC"
        passed=$((passed + 1))
    else
        reason="WA"
    fi

    echo "[INFO] time: ${elapsed} sec"
    if [ "$status" = "SUCCESS" ]; then
        echo "[SUCCESS] $reason"
    else
        if [ -s "$stderr_file" ]; then
            cat "$stderr_file" >&2
        fi
        echo "[FAILURE] $reason"
        echo "input:"
        print_case_input "$input_file"
        echo
        echo "output:"
        print_file_or_empty "$actual_file"
        echo "expected:"
        if [ -f "$expected_file" ]; then
            print_file_or_empty "$expected_file"
        else
            echo '(missing)'
        fi
    fi
    echo

    rm -f "$actual_file" "$stderr_file" "$timeout_file"
done

echo "[INFO] slowest: ${slowest_time} sec  (for $slowest_case)"
if [ "$passed" -eq "${#input_files[@]}" ]; then
    echo "[SUCCESS] test success: $passed cases"
else
    echo "[FAILURE] test failed: $passed AC / ${#input_files[@]} cases"
    exit 1
fi
