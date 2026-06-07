# carcom-oj

`cargo-compete` を [`online-judge-tool`](https://github.com/online-judge-tools/oj) (`oj`) と
[`online-judge-api-client`](https://github.com/online-judge-tools/api-client) (`oj-api`)、そして
[`cargo-equip`](https://github.com/qryxip/cargo-equip) を組み合わせて Just + 薄い shell で再現したワークフロー。

- 対応サイト: AtCoder / Codeforces / yukicoder
- 言語: Rust(AtCoder の Rust 1.70.0 を基準)
- 提出方法: `cargo-equip` で単一ファイルにバンドル → `oj submit`

## セットアップ

```sh
brew install just jq yq uv
just setup
cargo install cargo-equip
rustup install 1.70.0
```

`just setup` はリポジトリ直下に `.venv` を作成し、`online-judge-tools` (`oj`)、
`online-judge-api-client` (`oj-api`)、Selenium などの Python 依存をそこへ入れる。
依存は `pyproject.toml` に定義し、`uv.lock` で固定している。各 `just` レシピは
このローカル `.venv` の `oj` / `oj-api` だけを使う。

リポジトリのルートで `just login atcoder` を一度実行して Cookie を取得する。
Selenium が入っていればブラウザログインが起動する(`brew install --cask firefox && brew install geckodriver` 等)。

## 主要コマンド

すべて `just <recipe>` 形式。レシピ一覧は `just` で表示。

| レシピ | 役割 |
| --- | --- |
| `just login SITE` | ログイン (`atcoder` / `codeforces` / `yukicoder`) |
| `just new CONTEST_URL` | コンテスト一括生成。サンプルも全問 DL |
| `just add CONTEST PROBLEM_URL` | 既存パッケージに 1 問追加 |
| `just dl CONTEST ALIAS` | サンプル再取得 |
| `just test CONTEST ALIAS [...]` | `cargo build --release --bin ALIAS` → `oj test` |
| `just submit CONTEST ALIAS [...]` | テスト → `cargo equip` でバンドル → `oj submit` |
| `just open CONTEST ALIAS` | 問題ページをブラウザで開く |
| `just ls CONTEST` | 問題一覧 |

`just test` / `just submit` の追加引数はそのまま `oj test` / `oj submit` に渡る
(`just test abc300 a -- -e 1e-6` で浮動小数誤差許容、`just submit abc300 a -- --no-test --yes` 等)。

## 典型ワークフロー

```sh
just login atcoder
just new https://atcoder.jp/contests/abc300
$EDITOR contests/abc300/src/bin/a.rs
just test abc300 a
just submit abc300 a
```

## ディレクトリ構造

```
carcom-oj/
├── Justfile                    # エントリポイント
├── config.toml                 # 言語ID・toolchain・bundle 設定
├── rust-toolchain.toml         # rustc 1.70.0 (AtCoder と一致)
├── Cargo.toml                  # workspace ルート (members = ["cp-lib", "contests/*"])
├── cp-lib/                     # 共通ライブラリ。cargo-equip でインライン展開される
├── templates/                  # コンテスト/問題ひな形
├── scripts/                    # justfile から呼ばれる薄い shell
└── contests/<contest>/
    ├── Cargo.toml              # workspace member。各問題は [[bin]]
    ├── src/bin/<alias>.rs      # 1 問 = 1 binary
    ├── tests/<alias>/          # oj download が置く sample-*.in/.out
    └── meta.json               # alias ↔ URL/title/TLE/MLE
```

## 設定 (`config.toml`)

| キー | 役割 |
| --- | --- |
| `rust.profile` | `release` 推奨(`debug` は AtCoder で TLE になりやすい) |
| `bundle.extra_args` | `cargo equip` に渡す追加引数 |
| `test.auto_before_submit` | `submit` の前に自動でテストを走らせるか |
| `<site>.language_id` | 提出時のデフォルト言語 ID。`oj-api guess-language-id` で上書きされる |

## 制限・既知の挙動

- `oj submit` は filename 必須なので `/tmp/carcom-<contest>-<alias>.rs` を経由する。
- 提出ステータスの実時間監視(`cargo compete watch submissions` 相当)は実装していない。
  AtCoder のときは提出後に `~/Submissions/me` ページが自動で開く。
- システムテスト取得 (`oj download --system`) は未実装。手動で `--system` を加えれば取れる。
- AtCoder の rated 参加申請は実装していない。事前にブラウザで参加ボタンを押すこと。

## ライブラリの育て方

`cp-lib/src/lib.rs` に `pub mod foo;` を増やすだけ。
提出時に `cargo equip` が `use cp_lib::foo;` の参照を辿って単一ファイルへ畳み込む。
未使用 `mod` は同ツールで自動削除される。
