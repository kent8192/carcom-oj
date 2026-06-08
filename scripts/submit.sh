#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

contest="${1:?usage: submit.sh CONTEST ALIAS [--no-test] [--yes] [extra oj submit args]}"
alias_="${2:?usage: submit.sh CONTEST ALIAS [--no-test] [--yes] [extra oj submit args]}"
shift 2
require_local_python_env oj oj-api
require_cmd cargo oj oj-api jq yq python3 rustfmt
ensure_oj_runtime

pkg_dir="$CONTESTS_DIR/$contest"
[ -d "$pkg_dir" ] || die "contest not found: $pkg_dir"

url="$(meta_get "$contest" --arg a "$alias_" \
    '.problems[] | select(.alias==$a) | .url')"
[ -n "$url" ] && [ "$url" != "null" ] \
    || die "alias '$alias_' not found in $contest"

site="$(meta_get "$contest" '.site')"

# Parse optional flags. Anything else is forwarded to `oj submit`.
no_test=0
oj_extra=()
while [ $# -gt 0 ]; do
    case "$1" in
        --no-test) no_test=1 ;;
        --) shift; oj_extra+=("$@"); break ;;
        *) oj_extra+=("$1") ;;
    esac
    shift
done

# Pre-test (cargo-compete behavior: AC before submission).
auto_pre="$(cfg_get test.auto_before_submit)"
if [ "$no_test" -eq 0 ] && [ "$auto_pre" = "true" ]; then
    info "running pre-submit tests (use --no-test to skip)"
    "$ROOT/scripts/test.sh" "$contest" "$alias_"
fi

# Bundle local cp-lib into a single Rust source file.
bundled="/tmp/carcom-${contest}-${alias_}.rs"
info "bundling local cp-lib -> $bundled"
python3 "$ROOT/scripts/bundle.py" "$contest" "$alias_" >"$bundled"
rustfmt "$bundled"

# Resolve language id: prefer oj-api guess, fallback to config.toml default.
lang_default="$(cfg_get "${site}.language_id")"
lang_id="$lang_default"
guessed=""
if guessed="$(oj-api guess-language-id "$url" --file "$bundled" 2>/dev/null \
    | jq -r '.result.id // empty')"; then
    if [ -n "$guessed" ]; then
        lang_id="$guessed"
    fi
fi

info "submitting $url  (language=$lang_id${guessed:+, guessed})"
oj submit "$url" "$bundled" --language "$lang_id" "${oj_extra[@]}"

# Open submissions page on AtCoder (substitute for `cargo compete watch submissions`).
if [ "$site" = "atcoder" ]; then
    contest_part="$(echo "$url" | sed -E 's|(.*/contests/[^/]+).*|\1|')"
    info "opening $contest_part/submissions/me"
    open "$contest_part/submissions/me" 2>/dev/null || true
fi
