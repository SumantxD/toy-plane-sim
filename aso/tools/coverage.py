#!/usr/bin/env python3
"""P1/P2 term coverage of a listing: a term counts as covered when every word in it (filler and
'game(s)' excepted) appears in the name, subtitle or keyword field.
Usage: python3 coverage.py LISTING.json [...]"""
import json, sys
from pathlib import Path
from validate_metadata import words, stem, FILLER, GENERIC

KW = json.loads((Path(__file__).resolve().parent.parent / "data" / "keywords.json").read_text())["keywords"]

for path in sys.argv[1:]:
    L = json.loads(Path(path).read_text())
    have = {stem(w) for w in words(" ".join([L["name"], L["subtitle"], L["keywords"].replace(",", " ")]))}
    print(Path(path).name)
    for pr in ("P1", "P2"):
        terms = [k["term"] for k in KW if k["priority"] == pr]
        hit = [t for t in terms if {stem(w) for w in words(t)} - FILLER - {stem(g) for g in GENERIC} <= have]
        print(f"  {pr} {len(hit)}/{len(terms)}  missing: {', '.join(t for t in terms if t not in hit) or '-'}")
