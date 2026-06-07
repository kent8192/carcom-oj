#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

contest="${1:?usage: add.sh CONTEST PROBLEM_URL}"
problem_url="${2:?usage: add.sh CONTEST PROBLEM_URL}"
require_cmd oj oj-api jq yq
ensure_oj_runtime

pkg_dir="$CONTESTS_DIR/$contest"
[ -d "$pkg_dir" ] || die "contest not found: $pkg_dir (run 'just new ...' first)"

alias_="$(alias_from_url "$problem_url")"
[ -n "$alias_" ] || die "could not derive alias from URL: $problem_url"

existing="$(meta_get "$contest" --arg a "$alias_" \
    '.problems[] | select(.alias==$a) | .alias' || true)"
[ -z "$existing" ] || die "alias '$alias_' already exists in $contest"

info "fetching problem metadata: $problem_url"
p_full="$(oj-api get-problem "$problem_url")"
[ "$(echo "$p_full" | jq -r '.status')" = "ok" ] \
    || die "oj-api get-problem failed: $p_full"

time_limit="$(echo "$p_full" | jq -r '.result.timeLimit // 2000')"
memory_limit="$(echo "$p_full" | jq -r '.result.memoryLimit // 256')"
full_name="$(echo "$p_full" | jq -r '.result.name // ""')"

# Append [[bin]] to Cargo.toml.
cat >> "$pkg_dir/Cargo.toml" <<EOF

[[bin]]
name = "$alias_"
path = "src/bin/$alias_.rs"
EOF

cp "$TEMPLATES_DIR/main.rs.tmpl" "$pkg_dir/src/bin/$alias_.rs"

meta_set "$contest" \
    --arg alias "$alias_" \
    --arg name "$full_name" \
    --arg url "$problem_url" \
    --argjson tle "$time_limit" \
    --argjson mle "$memory_limit" \
    '.problems += [{alias:$alias, name:$name, url:$url, timeLimit:$tle, memoryLimit:$mle}]'

mkdir -p "$pkg_dir/tests/$alias_"
if ! oj download --silent "$problem_url" -d "$pkg_dir/tests/$alias_/" >/dev/null 2>&1; then
    info "(sample download failed; you can retry with: just dl $contest $alias_)"
fi

info "added [$alias_] $full_name"
