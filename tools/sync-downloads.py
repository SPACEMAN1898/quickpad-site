#!/usr/bin/env python3
"""Rewrite the no-JavaScript download list in index.html from the DOWNLOADS object at the top of its script.

    python3 tools/sync-downloads.py          # rewrite the list
    python3 tools/sync-downloads.py --check  # exit 1 if the list is out of date, or a listed file's size/SHA-256 is wrong

The markup must match card() in index.html's script, so the page looks the same with JavaScript on or off.
"""
import hashlib, html, json, os, re, sys

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = os.path.join(SITE, "index.html")
BEGIN = "<!-- BEGIN generated downloads: run `python3 tools/sync-downloads.py` after editing DOWNLOADS -->\n"
END = "<!-- END generated downloads -->"


def kb(n):
    return f"{max(1, round(n / 1024))} KB"


def card(key, d):
    e = lambda s: html.escape(str(s), quote=True)
    h = (f'<article class="dcard" data-key="{e(key)}" data-os="{e(d["os"])}" '
         f'data-available="{"true" if d["available"] else "false"}">\n'
         f'  <h4>{e(d["label"])}</h4>\n  <p class="dneeds">{e(d["needs"])}</p>\n')
    if d["available"]:
        h += f'  <a class="dfile" href="download/{e(d["file"])}" download>{e(d["file"])}</a>\n'
    else:
        h += '  <span class="dsoon">Coming soon</span>\n'
    h += f'  <p class="dmeta">Version {e(d["version"])}{" · " + kb(d["size"]) if d["available"] and d["size"] else ""}</p>\n'
    if d["available"]:
        h += f'  <p class="dhint">{e(d["hint"])}</p>\n'
    if d["available"] and d["sha256"]:
        h += f'  <p class="dsha">SHA-256 <code>{e(d["sha256"])}</code></p>\n'
    return h + "</article>"


def main():
    check = "--check" in sys.argv[1:]
    page = open(PAGE, encoding="utf-8").read()
    m = re.search(r"/\*BEGIN DOWNLOADS\*/(.*?)/\*END DOWNLOADS\*/", page, re.S)
    if not m:
        sys.exit("DOWNLOADS markers not found in index.html")
    downloads = json.loads(m.group(1))

    problems = []
    for key, d in downloads.items():
        path = os.path.join(SITE, "download", d["file"])
        if not d["available"]:
            continue
        if not os.path.isfile(path):
            problems.append(f"{key}: download/{d['file']} is missing")
            continue
        data = open(path, "rb").read()
        if d["size"] != len(data):
            problems.append(f"{key}: size is {len(data)}, DOWNLOADS says {d['size']}")
        if d["sha256"] != hashlib.sha256(data).hexdigest():
            problems.append(f"{key}: sha256 is {hashlib.sha256(data).hexdigest()}, DOWNLOADS says {d['sha256']}")

    start, stop = page.find(BEGIN), page.find(END)
    if start < 0 or stop < 0:
        sys.exit("generated-list markers not found in index.html")
    block = "\n".join(card(k, d) for k, d in downloads.items()) + "\n"
    new = page[:start + len(BEGIN)] + block + page[stop:]

    if check:
        if new != page:
            problems.append("the no-JavaScript list is out of date: run python3 tools/sync-downloads.py")
    elif new != page:
        open(PAGE, "w", encoding="utf-8").write(new)
        print("index.html: no-JavaScript download list updated")
    else:
        print("index.html: no-JavaScript download list already up to date")
    for p in problems:
        print("PROBLEM:", p)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
