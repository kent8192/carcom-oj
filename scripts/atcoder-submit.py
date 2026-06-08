#!/usr/bin/env python3
"""Submit code to AtCoder without online-judge-tools problem-page parsing."""

from __future__ import annotations

import argparse
import sys
import time
from http.cookiejar import LWPCookieJar
from pathlib import Path
from urllib.parse import urljoin, urlparse

import bs4
import requests


DEFAULT_COOKIE = Path.home() / "Library/Application Support/online-judge-tools/cookie.jar"


class SubmitError(Exception):
    pass


def parse_problem_url(url: str) -> tuple[str, str, str]:
    parts = [part for part in urlparse(url).path.split("/") if part]
    try:
        contest_index = parts.index("contests")
        tasks_index = parts.index("tasks")
        contest = parts[contest_index + 1]
        task = parts[tasks_index + 1]
    except (ValueError, IndexError) as exc:
        raise SubmitError(f"unsupported AtCoder problem URL: {url}") from exc
    contest_url = f"https://atcoder.jp/contests/{contest}"
    return contest, task, contest_url


def load_cookie(path: Path) -> LWPCookieJar:
    if not path.is_file():
        raise SubmitError(f"cookie jar not found: {path}; run just login-cookie")
    jar = LWPCookieJar(str(path))
    try:
        jar.load(ignore_discard=True, ignore_expires=True)
    except OSError as exc:
        raise SubmitError(f"failed to load cookie jar {path}: {exc}") from exc
    return jar


def fetch_submit_page(session: requests.Session, submit_url: str) -> bs4.BeautifulSoup:
    response = session.get(submit_url, timeout=20)
    response.raise_for_status()
    if "/login" in response.url:
        raise SubmitError("AtCoder session is not logged in; run just login-cookie")
    return bs4.BeautifulSoup(response.text, "html.parser")


def csrf_token(soup: bs4.BeautifulSoup) -> str:
    token = soup.find("input", {"name": "csrf_token"})
    if token is None or not token.get("value"):
        raise SubmitError("csrf_token not found on AtCoder submit page")
    return str(token["value"])


def ensure_task_exists(soup: bs4.BeautifulSoup, task: str) -> None:
    select = soup.find("select", {"name": "data.TaskScreenName"})
    if select is None:
        raise SubmitError("task selector not found on AtCoder submit page")
    if select.find("option", {"value": task}) is None:
        raise SubmitError(f"task {task} not found on AtCoder submit page")


def resolve_language(
    soup: bs4.BeautifulSoup,
    task: str,
    language_id: str,
    language_name: str | None,
) -> tuple[str, str]:
    container = soup.find(id=f"select-lang-{task}") or soup.find(id="select-lang")
    if container is None:
        raise SubmitError("language selector not found on AtCoder submit page")

    options = [
        (str(option.get("value")), option.get_text(" ", strip=True))
        for option in container.find_all("option")
        if option.get("value")
    ]
    for value, label in options:
        if value == language_id:
            return value, label

    if language_name:
        for value, label in options:
            if label == language_name:
                print(
                    f"warning: configured language id {language_id} is not available; "
                    f"using {value} for {language_name}",
                    file=sys.stderr,
                )
                return value, label

    rust_options = ", ".join(f"{value}: {label}" for value, label in options if "Rust" in label)
    detail = f"; Rust options: {rust_options}" if rust_options else ""
    raise SubmitError(f"language id {language_id} not found for {task}{detail}")


def confirm(args: argparse.Namespace, language_id: str, language_label: str, code: str) -> None:
    if args.dry_run:
        print(
            f"dry-run: would submit {args.file} to {args.url} "
            f"with language {language_id} ({language_label}); {len(code.encode('utf-8'))} bytes"
        )
        return
    if args.yes:
        return
    print(f"submit: {args.url}")
    print(f"file: {args.file}")
    print(f"language: {language_id} ({language_label})")
    answer = input("submit? [y/N] ")
    if answer.lower() not in ("y", "yes"):
        raise SubmitError("submission cancelled")


def submit(
    session: requests.Session,
    submit_url: str,
    task: str,
    token: str,
    language_id: str,
    code: str,
) -> str:
    response = session.post(
        submit_url,
        data={
            "data.TaskScreenName": task,
            "data.LanguageId": language_id,
            "sourceCode": code,
            "csrf_token": token,
        },
        timeout=30,
        allow_redirects=False,
    )
    if response.status_code not in (302, 303):
        raise SubmitError(f"AtCoder submit failed: HTTP {response.status_code}")
    location = response.headers.get("Location")
    if not location:
        raise SubmitError("AtCoder submit response did not include Location header")
    return urljoin(submit_url, location)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Submit code to AtCoder.")
    parser.add_argument("url", help="AtCoder problem URL")
    parser.add_argument("--file", required=True, type=Path)
    parser.add_argument("--language", required=True)
    parser.add_argument("--language-name")
    parser.add_argument("--cookie", default=DEFAULT_COOKIE, type=Path)
    parser.add_argument("-y", "--yes", action="store_true", help="do not confirm")
    parser.add_argument("--dry-run", action="store_true", help="validate form without submitting")
    parser.add_argument("--no-open", action="store_true", help="do not open the submission URL")
    parser.add_argument("--open", dest="open_", action="store_true", help="open the submission URL")
    parser.add_argument("-w", "--wait", type=float, default=0.0, help="sleep before submitting")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if not args.file.is_file():
            raise SubmitError(f"source file not found: {args.file}")
        code = args.file.read_text(encoding="utf-8")
        _contest, task, contest_url = parse_problem_url(args.url)
        submit_url = f"{contest_url}/submit"

        session = requests.Session()
        session.cookies.update(load_cookie(args.cookie))
        soup = fetch_submit_page(session, submit_url)
        token = csrf_token(soup)
        ensure_task_exists(soup, task)
        language_id, language_label = resolve_language(
            soup, task, args.language, args.language_name
        )
        confirm(args, language_id, language_label, code)
        if args.dry_run:
            return 0
        if args.wait > 0:
            time.sleep(args.wait)
        submission_url = submit(session, submit_url, task, token, language_id, code)
        print(submission_url)
        return 0
    except (OSError, requests.RequestException, SubmitError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
