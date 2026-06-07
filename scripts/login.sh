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

info "logging in to $site ($url)"
exec oj login "$url"
