#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

site="${1:?usage: login.sh SITE  (atcoder|codeforces|yukicoder)}"
require_local_python_env oj
require_cmd oj yq
ensure_oj_runtime

url="$(cfg_get "${site}.url")"
[ -n "$url" ] && [ "$url" != "null" ] || die "unknown site: $site (check config.toml)"

use_browser="${OJ_USE_BROWSER:-never}"
case "$use_browser" in
    always|auto|never) ;;
    *) die "invalid OJ_USE_BROWSER: $use_browser (expected: always|auto|never)" ;;
esac

info "logging in to $site ($url; browser=$use_browser)"
exec oj login --use-browser "$use_browser" "$url"
