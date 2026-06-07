#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

contest="${1:?usage: test.sh CONTEST ALIAS [extra oj test args]}"
alias_="${2:?usage: test.sh CONTEST ALIAS [extra oj test args]}"
shift 2
require_cmd cargo oj jq yq
ensure_oj_runtime

pkg_dir="$CONTESTS_DIR/$contest"
[ -d "$pkg_dir" ] || die "contest not found: $pkg_dir"

url="$(meta_get "$contest" --arg a "$alias_" \
    '.problems[] | select(.alias==$a) | .url')"
[ -n "$url" ] && [ "$url" != "null" ] \
    || die "alias '$alias_' not found in $contest"

tle_ms="$(meta_get "$contest" --arg a "$alias_" \
    '(.problems[] | select(.alias==$a) | .timeLimit) // 2000')"
tle_sec="$(awk "BEGIN{printf \"%.3f\", $tle_ms/1000}")"

profile="$(cfg_get rust.profile)"
if [ "$profile" = "release" ]; then
    build_flags=(--release)
    bin_dir="$ROOT/target/release"
else
    build_flags=()
    bin_dir="$ROOT/target/debug"
fi

info "building $contest::$alias_  (profile=$profile)"
cargo build "${build_flags[@]}" \
    --manifest-path "$pkg_dir/Cargo.toml" \
    --bin "$alias_"

bin_path="$bin_dir/$alias_"
[ -x "$bin_path" ] || die "binary not produced: $bin_path"

tests_dir="$pkg_dir/tests/$alias_"
[ -d "$tests_dir" ] || die "no test directory: $tests_dir (run 'just dl $contest $alias_')"

info "running oj test  (TLE=${tle_sec}s)"
exec oj test \
    -c "$bin_path" \
    -d "$tests_dir/" \
    --tle "$tle_sec" \
    "$@"
