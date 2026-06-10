#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

contest_url="${1:?usage: new.sh CONTEST_URL}"
require_local_python_env oj oj-api
require_cmd oj oj-api jq yq
ensure_oj_runtime

site="$(detect_site "$contest_url")"
contest_id="$(contest_id_from_url "$contest_url")"
[ -n "$contest_id" ] || die "could not derive contest id from URL: $contest_url"

pkg_dir="$CONTESTS_DIR/$contest_id"
[ -d "$pkg_dir" ] && die "contest dir already exists: $pkg_dir"

info "fetching contest metadata: $contest_url"
contest_json="$("$ROOT/.venv/bin/python" "$SCRIPT_DIR/atcoder-metadata.py" contest "$contest_url")"
status="$(echo "$contest_json" | jq -r '.status')"
[ "$status" = "ok" ] || die "fetch contest metadata failed: $contest_json"

problem_count="$(echo "$contest_json" | jq '.result.problems | length')"
[ "$problem_count" -gt 0 ] || die "contest has no problems"
download_timeout_sec="$(cfg_get download.timeout_sec)"

info "creating package: $pkg_dir ($problem_count problems)"
mkdir -p "$pkg_dir/src/bin" "$pkg_dir/tests"

# Render Cargo.toml from template (replace __CONTEST__).
sed -e "s/__CONTEST__/$contest_id/g" \
    "$TEMPLATES_DIR/contest-Cargo.toml.tmpl" \
    > "$pkg_dir/Cargo.toml"

# Build all sources before downloading samples. This keeps later problems
# available even if an earlier sample download stalls.
p_urls=()
p_aliases=()

for i in $(seq 0 $((problem_count - 1))); do
    p_url="$(echo "$contest_json" | jq -r ".result.problems[$i].url")"
    p_alias="$(echo "$contest_json" | jq -r ".result.problems[$i].alias")"
    [ -n "$p_alias" ] || die "could not derive alias from URL: $p_url"

    info "  [$p_alias] $p_url"
    p_urls+=("$p_url")
    p_aliases+=("$p_alias")

    # Append [[bin]] entry.
    cat >> "$pkg_dir/Cargo.toml" <<EOF

[[bin]]
name = "$p_alias"
path = "src/bin/$p_alias.rs"
EOF

    # Source skeleton.
    cp "$TEMPLATES_DIR/main.rs.tmpl" "$pkg_dir/src/bin/$p_alias.rs"
done

# Write meta.json.
problems_arr="$(echo "$contest_json" | jq -c '.result.problems')"
jq -n \
    --arg contest "$contest_id" \
    --arg site "$site" \
    --arg url "$contest_url" \
    --argjson problems "$problems_arr" \
    '{contest:$contest, site:$site, url:$url, problems:$problems}' \
    > "$pkg_dir/meta.json"

# Sample cases. A single stalled `oj download` must not block creation of later
# problem files.
for i in "${!p_aliases[@]}"; do
    p_alias="${p_aliases[$i]}"
    p_url="${p_urls[$i]}"
    mkdir -p "$pkg_dir/tests/$p_alias"
    if ! "$ROOT/.venv/bin/python" "$SCRIPT_DIR/run-with-timeout.py" "$download_timeout_sec" \
        oj download --silent "$p_url" -d "$pkg_dir/tests/$p_alias/" >/dev/null 2>&1; then
        info "    (sample download failed or timed out for $p_alias; skipping)"
    fi
done

# Register this contest as a workspace member of the root Cargo.toml.
register_workspace_member "contests/$contest_id"

first_alias="$(jq -r '.problems[0].alias' "$pkg_dir/meta.json")"
info "done. try:  just test $contest_id $first_alias"
