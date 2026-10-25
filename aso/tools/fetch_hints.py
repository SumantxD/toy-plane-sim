# App Store search hints (autocomplete) per storefront. Output: aso/data/raw_hints.json
import json, plistlib, time, urllib.parse, urllib.request, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from kw_terms import TERMS
SF = {"us": "143441-1,29", "in": "143467-1,29"}
URL = "https://search.itunes.apple.com/WebObjects/MZSearchHints.woa/wa/hints?clientApplication=Software&term="
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "raw_hints.json")
cache = {}
def hints(q, cc):
    k = (q, cc)
    if k in cache: return cache[k]
    req = urllib.request.Request(URL + urllib.parse.quote(q), headers={"X-Apple-Store-Front": SF[cc], "User-Agent": "Mozilla/5.0"})
    for i in range(3):
        try:
            d = plistlib.loads(urllib.request.urlopen(req, timeout=20).read())
            cache[k] = [h["term"] for h in d.get("hints", [])]
            break
        except Exception as e:
            cache[k] = {"error": str(e)}; time.sleep(2)
    time.sleep(0.35)
    return cache[k]
def prefixes(t):
    w = t.split(" "); out = []
    out.append(w[0][:min(3, len(w[0]))])
    out.append(w[0])
    for i in range(1, len(w)):
        base = " ".join(w[:i]) + " "
        out.append(base + w[i][0]); out.append(base + w[i])
    seen = []
    for p in out:
        if p not in seen: seen.append(p)
    return seen
# optional: python3 fetch_hints.py "term" ... fetches only those and merges into the existing file
ONLY = sys.argv[1:]
res = json.load(open(OUT))["data"] if ONLY and os.path.exists(OUT) else {}
for g, t in TERMS:
    if ONLY and t not in ONLY: continue
    res[t] = {}
    for cc in SF:
        full = hints(t, cc)
        V = [t, t[:-1] if t.endswith("s") else t + "s"]  # singular/plural counts as the same keyword
        hit = lambda h: next((v for v in h if v in V), None) if isinstance(h, list) else None
        pos = full.index(hit(full)) + 1 if hit(full) else None
        shortest = None
        for p in prefixes(t):
            h = hints(p, cc)
            if hit(h):
                shortest = {"prefix": p, "chars": len(p), "matched": hit(h), "position": h.index(hit(h)) + 1, "hints": h}; break
        res[t][cc] = {"full_term_hints": full, "exact_in_full_hints_pos": pos, "shortest_prefix": shortest,
                      "prefixes_tested": prefixes(t)}
    print(t, {c: (res[t][c]["shortest_prefix"] or {}).get("prefix") for c in SF}, flush=True)
now = time.strftime("%Y-%m-%d %H:%M:%S %Z")
fetched = f'{json.load(open(OUT))["fetched"]}; {", ".join(ONLY)} at {now}' if ONLY else now
json.dump({"fetched": fetched, "endpoint": URL, "storefronts": SF, "data": res}, open(OUT, "w"), indent=1)
