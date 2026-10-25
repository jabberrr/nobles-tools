"""Prints the parts of an HTML page that matter for scraping: inline scripts,
data-* attributes, feed-like URLs and the body with presentation noise removed."""
import re
import sys

path, limit = sys.argv[1], int(sys.argv[2])
html = open(path, encoding="utf-8", errors="replace").read()

print("-- scripts:")
for attrs, body in re.findall(r"(?is)<script\b([^>]*)>(.*?)</script>", html):
    code = re.sub(r"\s+", " ", body)[:2500]
    print(f"[script {attrs.strip()}] {code}")

print("-- data attributes:")
for name, count in sorted({m: html.count(m) for m in re.findall(r"\bdata-[a-z_-]+(?==)", html)}.items()):
    print(f"{count:5} {name}")

print("-- feed-like URLs:")
for url in sorted(set(re.findall(r"""[^\s"'<>()]*(?:webcal:|\.ics|ical|json|rss|\.xml|\.php\?)[^\s"'<>()]*""", html, re.I)))[:80]:
    print(url)

body = re.sub(r"(?is)<(head|script|style|svg|noscript)\b.*?</\1>", "", html)
body = re.sub(r"(?is)<img\b[^>]*>|<!--.*?-->", "", body)
body = re.sub(r"\s+", " ", body)
print(f"-- cleaned body ({len(body)} chars, first {limit}):")
print(body[:limit])
