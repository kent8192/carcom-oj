# carcom-oj

A Rust workspace template for competitive programming.

This repository recreates the main `cargo-compete` workflow with
[`online-judge-tools`](https://github.com/online-judge-tools/oj) (`oj`),
[`online-judge-api-client`](https://github.com/online-judge-tools/api-client)
(`oj-api`), [`cargo-equip`](https://github.com/qryxip/cargo-equip), Just, and
small shell scripts.

- Supported sites: AtCoder / Codeforces / yukicoder
- Language: Rust, targeting AtCoder's Rust 1.89.0 / edition 2024 environment
- Submission flow: bundle into a single file with `cargo-equip`, then submit with `oj submit`

## Use As A Template

Create your own repository from GitHub's `Use this template`, or clone it and replace the remote.

```sh
git clone <your-repository-url> my-oj
cd my-oj
git remote -v
```

Rename the visible project name if needed. This is not required for functionality, but it is worth doing early if the repository will be shared.

```sh
perl -pi -e 's/carcom-oj/my-oj/g' README.md pyproject.toml
```

The intended template state has an empty `contests/` directory and no generated contests committed. If you delete generated contests to restore the template state, also reset `Cargo.toml` workspace members to only `["cp-lib"]`.

```toml
members = ["cp-lib"]
```

## Setup

Example for macOS.

```sh
brew install just jq yq uv
rustup install 1.89.0
cargo install cargo-equip
just setup
```

`just setup` creates a repository-local `.venv` and installs Python dependencies such as `online-judge-tools`, `online-judge-api-client`, and Selenium. Dependencies are declared in `pyproject.toml` and locked by `uv.lock`. Each `just` recipe prefers the local `.venv` versions of `oj` and `oj-api`.

AtCoder's login page uses Cloudflare Turnstile, so `oj`'s CUI login often cannot complete. Log in to AtCoder with a normal browser, copy the `REVEL_SESSION` cookie from developer tools, then import it.

```sh
ATCODER_REVEL_SESSION='...' just login-cookie
```

Only use the WebDriver login path when you explicitly want to try it.

```sh
OJ_USE_BROWSER=always just login atcoder
```

## Validation

Immediately after cloning the template, first check the dependencies and root workspace.

```sh
just
just setup
cargo check --workspace
cargo equip --version
```

Then validate contest generation and sample testing with a small AtCoder contest.

```sh
just new https://atcoder.jp/contests/abc001
just ls abc001
just test abc001 1
```

Right after `just new`, `1.rs` is only a TODO skeleton, so `just test abc001 1` will fail. For ABC001 1, solve `contests/abc001/src/bin/1.rs` and run the test again.

```rust
use proconio::input;

fn main() {
    input! {
        h1: i32,
        h2: i32,
    }

    println!("{}", h1 - h2);
}
```

To re-download samples:

```sh
just dl abc001 1
just test abc001 1
```

To open the problem page:

```sh
just open abc001 1
```

Submit only after you are logged in and sample tests pass. This performs a real submission, so do not run it casually just for validation.

```sh
just submit abc001 1 -- --yes
```

## Commands

All commands use `just <recipe>`. Run `just` to list available recipes.

| Recipe | Purpose |
| --- | --- |
| `just setup` | Create `.venv` and sync Python dependencies |
| `just login SITE` | Log in (`atcoder` / `codeforces` / `yukicoder`) |
| `just login-cookie` | Import an AtCoder `REVEL_SESSION` copied from a browser |
| `just new CONTEST_URL` | Generate a contest package and download all sample cases |
| `just add CONTEST PROBLEM_URL` | Add one problem to an existing contest |
| `just dl CONTEST ALIAS` | Re-download samples |
| `just test CONTEST ALIAS [...]` | Run `cargo build`, then `oj test` |
| `just submit CONTEST ALIAS [...]` | Run tests, bundle with `cargo equip`, then `oj submit` |
| `just open CONTEST ALIAS` | Open the problem page in a browser |
| `just ls CONTEST` | List problems in a contest |

Extra arguments for `just test` and `just submit` are forwarded to `oj test` and `oj submit`.

```sh
just test abc300 a -- -e 1e-6
just submit abc300 a -- --no-test --yes
```

## Typical Workflow

```sh
just login-cookie
just new https://atcoder.jp/contests/abc300
$EDITOR contests/abc300/src/bin/a.rs
just test abc300 a
just submit abc300 a -- --yes
```

To add a single problem to an existing contest:

```sh
just add abc300 https://atcoder.jp/contests/abc300/tasks/abc300_b
just test abc300 b
```

## Directory Layout

```text
carcom-oj/
├── Justfile                    # Entry point
├── config.toml                 # Language IDs, toolchain, and bundling settings
├── rust-toolchain.toml         # rustc 1.89.0, matching AtCoder
├── Cargo.toml                  # Workspace root
├── cp-lib/                     # Shared library, inlined by cargo-equip
├── templates/                  # Contest and problem templates
├── scripts/                    # Shell scripts called by Justfile
└── contests/<contest>/
    ├── Cargo.toml              # Workspace member; each problem is a [[bin]]
    ├── src/bin/<alias>.rs      # One problem = one binary
    ├── tests/<alias>/          # sample-*.in/.out files from oj download
    └── meta.json               # Alias, URL, title, TLE, and MLE
```

## Configuration

Customize behavior in `config.toml`.

| Key | Purpose |
| --- | --- |
| `rust.profile` | `release` is recommended. `debug` is likely to TLE on AtCoder |
| `bundle.extra_args` | Extra arguments passed to `cargo equip` |
| `test.auto_before_submit` | Whether to run tests automatically before `submit` |
| `<site>.language_id` | Default submission language ID. Overridden when `oj-api guess-language-id` succeeds |

## Growing The Library

Add `pub mod foo;` to `cp-lib/src/lib.rs`, then use it from problems with `use cp_lib::foo;` or `use cp_lib::*;`. On submission, `cargo equip` follows references and folds the used code into a single file. Unused modules are removed automatically by the tool.

## Limitations And Known Behavior

- `oj submit` requires a filename, so submissions go through `/tmp/carcom-<contest>-<alias>.rs`.
- Real-time submission watching, equivalent to `cargo compete watch submissions`, is not implemented. For AtCoder, the submissions page is opened after submission.
- System test download, `oj download --system`, does not have a dedicated recipe. Run `oj download --system` manually if needed.
- Rated participation registration on AtCoder is not implemented. Press the participation button in your browser beforehand.
