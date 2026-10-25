# iTunes Search API competition snapshot per country. Output: aso/data/raw_search.json
import gzip, json, re, time, urllib.parse, urllib.request, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from kw_terms import TERMS
GENERIC = {"game", "games", "3d", "with", "the", "for", "गेम"}
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "raw_search.json")
# optional: python3 fetch_search.py "term" ... fetches only those and merges into the existing file
ONLY = sys.argv[1:]
res = json.load(open(OUT))["data"] if ONLY and os.path.exists(OUT) else {}
for g, t in TERMS:
    if ONLY and t not in ONLY: continue
    res[t] = {}
    for cc in ("in", "us"):
        u = "https://itunes.apple.com/search?" + urllib.parse.urlencode({"term": t, "entity": "software", "country": cc, "limit": 200})
        d = None
        for i in range(4):
            try:
                raw = urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0", "Accept-Encoding": "gzip"}), timeout=60).read()
                d = json.loads(gzip.decompress(raw) if raw[:2] == b"\x1f\x8b" else raw); break
            except Exception as e:
                err = str(e); time.sleep(20 * (i + 1))
        if d is None:
            res[t][cc] = {"error": err}; continue
        r = d.get("results", [])
        words = t.lower().split()
        content = [w for w in words if w not in GENERIC] or words
        has = lambda w, x: (re.search(r"\b" + re.escape(w.rstrip("s") if len(w) > 4 else w) + r"(s|es)?\b", x) is not None) if w.isascii() else w in x
        res[t][cc] = {
            "resultCount": d.get("resultCount"),
            "games_in_results": sum(1 for a in r if "Games" in a.get("genres", [])),
            "title_contains_all_words": sum(1 for a in r if all(w in a.get("trackName", "").lower() for w in words)),
            "top5": [{"id": a.get("trackId"), "name": a.get("trackName"), "seller": a.get("sellerName"),
                      "userRatingCount": a.get("userRatingCount", 0), "avg": a.get("averageUserRating"),
                      "genre": a.get("primaryGenreName")} for a in r[:5]],
            "seller_top10": [a.get("sellerName") for a in r[:10]],
            "top10_ratings": [a.get("userRatingCount", 0) for a in r[:10]],
            # top 25 slim: is it a game, and does it match the term (any content word in title, or all in description)
            "top25": [{"name": a.get("trackName"), "id": a.get("trackId"), "game": "Games" in a.get("genres", []),
                       "genre": a.get("primaryGenreName"), "ratings": a.get("userRatingCount", 0),
                       "title_hit": any(has(w, a.get("trackName", "").lower()) for w in content),
                       "desc_all": all(has(w, a.get("description", "").lower()) for w in content)} for a in r[:25]],
        }
        time.sleep(2)
    print(t, res[t]["in"].get("resultCount"), res[t]["us"].get("resultCount"), flush=True)
now = time.strftime("%Y-%m-%d %H:%M:%S %Z")
fetched = f'{json.load(open(OUT))["fetched"]}; {", ".join(ONLY)} at {now}' if ONLY else now
json.dump({"fetched": fetched, "params": "entity=software&limit=200", "data": res}, open(OUT, "w"), indent=1)
