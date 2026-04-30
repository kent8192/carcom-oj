#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

contest="${1:?usage: ls.sh CONTEST}"
require_cmd jq

pkg_dir="$CONTESTS_DIR/$contest"
[ -d "$pkg_dir" ] || die "contest not found: $pkg_dir"

printf '%-8s  %-2s  %-7s  %-44s  %s\n' "ALIAS" "OK" "TLE(s)" "NAME" "URL"
printf '%-8s  %-2s  %-7s  %-44s  %s\n' "-----" "--" "------" "----" "---"

jq -c '.problems[]' "$pkg_dir/meta.json" | while IFS= read -r row; do
    a="$(jq -r '.alias' <<<"$row")"
    n="$(jq -r '.name' <<<"$row")"
    u="$(jq -r '.url' <<<"$row")"
    tle_ms="$(jq -r '.timeLimit // 2000' <<<"$row")"
    tle_sec="$(awk "BEGIN{printf \"%.1f\", $tle_ms/1000}")"
    if [ -d "$pkg_dir/tests/$a" ] && \
       [ "$(find "$pkg_dir/tests/$a" -maxdepth 1 -name '*.in' | wc -l)" -gt 0 ]; then
        ok="✓"
    else
        ok="·"
    fi
    name_trunc="${n:0:42}"
    printf '%-8s  %-2s  %-7s  %-44s  %s\n' "$a" "$ok" "$tle_sec" "$name_trunc" "$u"
done
