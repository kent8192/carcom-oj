#!/usr/bin/env bash
# Common helpers for carcom-oj scripts.
# Source from other scripts AFTER `set -euo pipefail`.

# Resolve repository root from this script's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT/config.toml"
TEMPLATES_DIR="$ROOT/templates"
CONTESTS_DIR="$ROOT/contests"

die() {
    printf '\033[1;31merror\033[0m: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '\033[1;36m▶\033[0m %s\n' "$*" >&2
}

require_cmd() {
    local missing=()
    local c
    for c in "$@"; do
        command -v "$c" >/dev/null 2>&1 || missing+=("$c")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        die "missing required commands: ${missing[*]}"
    fi
}

# detect_site URL -> "atcoder" | "codeforces" | "yukicoder"
detect_site() {
    local url="$1"
    case "$url" in
        *atcoder.jp*)     echo "atcoder" ;;
        *codeforces.com*) echo "codeforces" ;;
        *yukicoder.me*)   echo "yukicoder" ;;
        *) die "unsupported site URL: $url" ;;
    esac
}

# contest_id_from_url URL -> e.g. "abc300", "cf-1850", "yk-123"
# Used as the contest package directory name.
contest_id_from_url() {
    local url="$1"
    local site
    site="$(detect_site "$url")"
    case "$site" in
        atcoder)
            # https://atcoder.jp/contests/abc300
            # https://atcoder.jp/contests/abc300/tasks/abc300_a
            echo "$url" | sed -E 's|.*/contests/([^/?#]+).*|\1|'
            ;;
        codeforces)
            # https://codeforces.com/contest/1850
            # https://codeforces.com/contest/1850/problem/F
            # https://codeforces.com/gym/12345/problem/A
            echo "$url" | sed -E 's|.*/(contest\|gym)/([0-9]+).*|cf-\2|'
            ;;
        yukicoder)
            # https://yukicoder.me/contests/123
            # https://yukicoder.me/problems/no/12345
            if [[ "$url" =~ /contests/([0-9]+) ]]; then
                echo "yk-${BASH_REMATCH[1]}"
            else
                echo "$url" | sed -E 's|.*/no/([0-9]+).*|yk-no-\1|'
            fi
            ;;
    esac
}

# alias_from_url URL -> e.g. "a" / "f" / "n12345"
alias_from_url() {
    local url="$1"
    local site
    site="$(detect_site "$url")"
    case "$site" in
        atcoder)
            # tasks/abc300_a -> a, tasks/abc300_ex -> ex
            local last
            last="$(echo "$url" | sed -E 's|.*/tasks/([^/?#]+).*|\1|')"
            echo "${last##*_}"
            ;;
        codeforces)
            # /problem/F -> f
            echo "$url" \
                | sed -E 's|.*/problem/([A-Za-z0-9]+).*|\1|' \
                | tr '[:upper:]' '[:lower:]'
            ;;
        yukicoder)
            # /no/12345 -> n12345
            echo "$url" | sed -E 's|.*/no/([0-9]+).*|n\1|'
            ;;
    esac
}

# cfg_get DOTTED_KEY  e.g. cfg_get "atcoder.language_id"
cfg_get() {
    local key="$1"
    yq -p toml -oy ".${key}" "$CONFIG_FILE"
}

# cfg_get_array DOTTED_KEY -> space-separated tokens
cfg_get_array() {
    local key="$1"
    yq -p toml -oy ".${key} | join(\" \")" "$CONFIG_FILE"
}

# meta_path CONTEST
meta_path() {
    echo "$CONTESTS_DIR/$1/meta.json"
}

# meta_get CONTEST [jq args...]
# Example: meta_get abc300 --arg a "$alias" '.problems[] | select(.alias==$a).url'
meta_get() {
    local contest="$1"; shift
    jq -r "$@" "$(meta_path "$contest")"
}

# meta_set CONTEST [jq args...] FILTER
# Atomically rewrites meta.json with the result of `jq FILTER`.
meta_set() {
    local contest="$1"; shift
    local file
    file="$(meta_path "$contest")"
    local tmp="${file}.tmp"
    jq "$@" "$file" >"$tmp" && mv "$tmp" "$file"
}

# register_workspace_member RELPATH
# Appends `"<RELPATH>"` to the `members = [...]` array in the root Cargo.toml.
# Idempotent: a no-op when the entry is already present.
register_workspace_member() {
    local member="$1"
    local cargo="$ROOT/Cargo.toml"
    local q="\"$member\""
    if grep -qF "$q" "$cargo"; then
        return 0
    fi
    local tmp="${cargo}.tmp"
    awk -v entry="$q" '
        BEGIN { added = 0 }
        added == 0 && /^members = \[/ {
            sub(/\]/, ", " entry "]")
            added = 1
        }
        { print }
    ' "$cargo" > "$tmp" && mv "$tmp" "$cargo"
}
