"""Cuts the "Upcoming Schedule" sidebar out of the Nobles Athletics home page,
keeping its markup byte-for-byte, so it can be stored as a small test fixture."""
import sys

html = open(sys.argv[1], encoding="utf-8", errors="replace").read()
start = html.find('<aside class="home-sidebar"')
end = html.find("</aside>", start)
if start < 0 or end < 0:
    sys.exit("Upcoming Schedule sidebar not found")
sys.stdout.write(html[start:end + len("</aside>")] + "\n")
