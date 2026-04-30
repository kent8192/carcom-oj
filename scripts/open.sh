#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

contest="${1:?usage: open.sh CONTEST ALIAS}"
alias_="${2:?usage: open.sh CONTEST ALIAS}"
require_cmd jq yq

url="$(meta_get "$contest" --arg a "$alias_" \
    '.problems[] | select(.alias==$a) | .url')"
[ -n "$url" ] && [ "$url" != "null" ] \
    || die "alias '$alias_' not found in $contest"

info "opening $url"
exec open "$url"
