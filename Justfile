set shell := ["bash", "-cu"]
set positional-arguments

ROOT := justfile_directory()

# List recipes
default:
    @just --list

# Create/update the project-local Python environment
setup:
    cd "{{ ROOT }}" && uv sync --locked

# Login to a judge (atcoder | codeforces | yukicoder)
login SITE:
    "{{ ROOT }}/scripts/login.sh" "$1"

# Import an AtCoder REVEL_SESSION cookie copied from a normal browser
login-cookie *ARGS:
    "{{ ROOT }}/.venv/bin/python" "{{ ROOT }}/scripts/import-atcoder-cookie.py" "$@"

# Create a new contest workspace from CONTEST_URL (downloads all sample cases)
new CONTEST_URL:
    "{{ ROOT }}/scripts/new.sh" "$1"

# Add a single problem to an existing contest package
add CONTEST PROBLEM_URL:
    "{{ ROOT }}/scripts/add.sh" "$1" "$2"

# (Re-)download samples for one problem
dl CONTEST ALIAS:
    "{{ ROOT }}/scripts/dl.sh" "$1" "$2"

# Build & run sample tests with the repo-local runner
test CONTEST ALIAS *EXTRA:
    "{{ ROOT }}/scripts/test.sh" "$@"

# Bundle local cp-lib and submit; extra: --no-test, --yes, plus oj submit args
submit CONTEST ALIAS *EXTRA:
    "{{ ROOT }}/scripts/submit.sh" "$@"

# Open the problem URL in a browser
open CONTEST ALIAS:
    "{{ ROOT }}/scripts/open.sh" "$1" "$2"

# List problems in a contest (alias / name / URL)
ls CONTEST:
    "{{ ROOT }}/scripts/ls.sh" "$1"
