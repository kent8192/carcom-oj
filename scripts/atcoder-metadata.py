#!/usr/bin/env python3
import argparse
import json
import pathlib
import re
import sys
from urllib.parse import urljoin, urlparse

import bs4
import requests


def parse_time_limit(value: str) -> int:
    match = re.fullmatch(r"([0-9.]+)\s*(msec|sec)", value.strip())
    if not match:
        raise ValueError(f"unsupported time limit: {value!r}")
    amount = float(match.group(1))
    return int(amount if match.group(2) == "msec" else amount * 1000)


def parse_memory_limit(value: str) -> int:
    match = re.fullmatch(r"([0-9.]+)\s*(KB|KiB|MB|MiB|GB|GiB)", value.strip())
    if not match:
        raise ValueError(f"unsupported memory limit: {value!r}")
    amount = float(match.group(1))
    unit = match.group(2)
    if unit in ("KB", "KiB"):
        return int(amount / 1000)
    if unit in ("MB", "MiB"):
        return int(amount)
    return int(amount * 1000)


def problem_alias(problem_url: str) -> str:
    task_id = pathlib.PurePosixPath(urlparse(problem_url).path).name
    return task_id.rsplit("_", 1)[-1].lower()


def parse_problem_title(text: str) -> tuple[str, str]:
    alphabet, sep, name = text.strip().partition(" - ")
    if not sep:
        return "", text.strip()
    return alphabet.strip(), name.strip()


def direct_text(tag: bs4.Tag) -> str:
    return " ".join(str(child).strip() for child in tag.children if isinstance(child, bs4.NavigableString) and str(child).strip())


def fetch_soup(session: requests.Session, url: str) -> bs4.BeautifulSoup:
    response = session.get(url, timeout=20)
    response.raise_for_status()
    response.encoding = "UTF-8"
    return bs4.BeautifulSoup(response.text, "html.parser")


def problem_from_page(session: requests.Session, url: str) -> dict[str, object]:
    soup = fetch_soup(session, url)
    heading = soup.select_one("span.h2")
    if heading is None:
        raise ValueError(f"problem heading not found: {url}")

    alphabet, name = parse_problem_title(direct_text(heading))
    limits = heading.find_next_sibling("p")
    if limits is None:
        raise ValueError(f"problem limits not found: {url}")
    match = re.search(r"Time Limit:\s*([^/]+)\s*/\s*Memory Limit:\s*(.+)", limits.get_text(" ", strip=True))
    if not match:
        raise ValueError(f"unsupported problem limits: {limits.get_text(' ', strip=True)!r}")

    return {
        "alias": problem_alias(url),
        "alphabet": alphabet,
        "name": name,
        "url": url,
        "timeLimit": parse_time_limit(match.group(1)),
        "memoryLimit": parse_memory_limit(match.group(2)),
    }


def contest_from_tasks_page(session: requests.Session, url: str) -> dict[str, object]:
    contest_url = url.rstrip("/")
    contest_id = pathlib.PurePosixPath(urlparse(contest_url).path).name
    tasks_url = urljoin(contest_url + "/", "tasks")
    soup = fetch_soup(session, tasks_url)
    tbody = soup.find("tbody")
    if tbody is None:
        raise ValueError(f"tasks table not found: {tasks_url}")

    problems: list[dict[str, object]] = []
    for row in tbody.find_all("tr"):
        cells = row.find_all("td")
        if len(cells) < 4:
            continue
        link = cells[1].find("a") or cells[0].find("a")
        if link is None or not link.get("href"):
            continue
        problem_url = urljoin("https://atcoder.jp", link["href"])
        problems.append(
            {
                "alias": problem_alias(problem_url),
                "alphabet": cells[0].get_text(" ", strip=True),
                "name": cells[1].get_text(" ", strip=True),
                "url": problem_url,
                "timeLimit": parse_time_limit(cells[2].get_text(" ", strip=True)),
                "memoryLimit": parse_memory_limit(cells[3].get_text(" ", strip=True)),
            }
        )

    if not problems:
        raise ValueError(f"no problems found: {tasks_url}")

    return {"contest": contest_id, "site": "atcoder", "url": contest_url, "problems": problems}


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch AtCoder contest/problem metadata without online-judge-tools parsers.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    contest_parser = subparsers.add_parser("contest")
    contest_parser.add_argument("url")
    problem_parser = subparsers.add_parser("problem")
    problem_parser.add_argument("url")
    args = parser.parse_args()

    session = requests.Session()
    try:
        if args.command == "contest":
            payload = contest_from_tasks_page(session, args.url)
        else:
            payload = {"status": "ok", "result": problem_from_page(session, args.url)}
    except Exception as exc:
        print(json.dumps({"status": "error", "message": str(exc)}, ensure_ascii=False))
        return 1

    if args.command == "contest":
        print(json.dumps({"status": "ok", "result": payload}, ensure_ascii=False))
    else:
        print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
