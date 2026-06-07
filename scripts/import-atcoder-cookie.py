#!/usr/bin/env python3
import argparse
import datetime
import getpass
import http.cookiejar
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
VENV_PYTHON = ROOT / ".venv/bin/python"
VENV_DIR = ROOT / ".venv"
if VENV_PYTHON.exists() and pathlib.Path(sys.prefix).resolve() != VENV_DIR.resolve():
    os.execv(str(VENV_PYTHON), [str(VENV_PYTHON), __file__, *sys.argv[1:]])

import requests

COOKIE_NAME = "REVEL_SESSION"
DOMAIN = "atcoder.jp"
SUBMIT_URL = "https://atcoder.jp/contests/agc001/submit"


def default_cookie_path() -> pathlib.Path:
    return pathlib.Path.home() / "Library/Application Support/online-judge-tools/cookie.jar"


def normalize_cookie_value(value: str) -> str:
    value = value.strip()
    if value.lower().startswith("cookie:"):
        value = value.split(":", 1)[1].strip()
    for part in value.split(";"):
        part = part.strip()
        if part.startswith(f"{COOKIE_NAME}="):
            value = part[len(COOKIE_NAME) + 1 :]
            break
    return value.strip().strip('"')


def make_cookie(value: str) -> http.cookiejar.Cookie:
    expires = int((datetime.datetime.now(datetime.UTC) + datetime.timedelta(days=180)).timestamp())
    return http.cookiejar.Cookie(
        version=0,
        name=COOKIE_NAME,
        value=value,
        port=None,
        port_specified=False,
        domain=DOMAIN,
        domain_specified=True,
        domain_initial_dot=False,
        path="/",
        path_specified=True,
        secure=True,
        expires=expires,
        discard=False,
        comment=None,
        comment_url=None,
        rest={"HttpOnly": None},
        rfc2109=False,
    )


def clear_cookie(jar: http.cookiejar.CookieJar) -> None:
    for domain in (DOMAIN, f".{DOMAIN}"):
        try:
            jar.clear(domain, "/", COOKIE_NAME)
        except KeyError:
            pass


def verify_login(jar: http.cookiejar.CookieJar) -> bool:
    session = requests.Session()
    session.cookies = jar
    response = session.get(SUBMIT_URL, allow_redirects=False, timeout=20)
    return response.status_code == 200


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Import an AtCoder REVEL_SESSION cookie into online-judge-tools cookie.jar."
    )
    parser.add_argument("--session", help="AtCoder REVEL_SESSION value. Defaults to ATCODER_REVEL_SESSION or a hidden prompt.")
    parser.add_argument("--cookie-jar", type=pathlib.Path, default=default_cookie_path())
    args = parser.parse_args()

    value = args.session or os.environ.get("ATCODER_REVEL_SESSION")
    if value is None:
        value = getpass.getpass("REVEL_SESSION: ")
    value = normalize_cookie_value(value)
    if not value:
        print("error: empty REVEL_SESSION", file=sys.stderr)
        return 1

    jar = http.cookiejar.LWPCookieJar(str(args.cookie_jar))
    if args.cookie_jar.exists():
        jar.load(ignore_discard=True)

    clear_cookie(jar)
    jar.set_cookie(make_cookie(value))
    args.cookie_jar.parent.mkdir(parents=True, exist_ok=True)
    jar.save(ignore_discard=True)
    args.cookie_jar.chmod(0o600)

    if verify_login(jar):
        print(f"imported AtCoder cookie and verified login: {args.cookie_jar}")
        return 0

    print("imported cookie, but AtCoder still reports you are not signed in", file=sys.stderr)
    print("check that you copied the REVEL_SESSION cookie from a currently logged-in browser session", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
