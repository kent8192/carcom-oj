#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

contest="${1:?usage: dl.sh CONTEST ALIAS}"
alias_="${2:?usage: dl.sh CONTEST ALIAS}"
require_cmd oj jq yq
ensure_oj_runtime

pkg_dir="$CONTESTS_DIR/$contest"
[ -d "$pkg_dir" ] || die "contest not found: $pkg_dir"

url="$(meta_get "$contest" --arg a "$alias_" \
    '.problems[] | select(.alias==$a) | .url')"
[ -n "$url" ] && [ "$url" != "null" ] \
    || die "alias '$alias_' not found in $contest (try 'just ls $contest')"

dir="$pkg_dir/tests/$alias_"
rm -rf "$dir"
mkdir -p "$dir"
info "downloading samples: $url -> $dir"
exec oj download "$url" -d "$dir/"
