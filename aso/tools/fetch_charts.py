# Top-free iPhone charts (iTunes RSS) for Games/Action (7001) and Games/Simulation (7015), IN and US,
# joined with Lookup API rating counts. Output: aso/data/charts.json. Prints the rating-count bar per rank band.
import json, os, re, statistics, time, urllib.request
D = os.path.join(os.path.dirname(__file__), "..", "data")
UA = {"User-Agent": "Mozilla/5.0"}
GENRES = {"7001": "Action", "7015": "Simulation"}
PLANE = re.compile(r"plane|air|jet|flight|fly|flying|pilot|sky|wing|aero|dogfight|1945|fighter", re.I)
get = lambda u: json.loads(urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=60).read())
out = {"fetched": time.strftime("%Y-%m-%d %H:%M %Z"), "source": "https://itunes.apple.com/<cc>/rss/topfreeapplications/limit=200/genre=<id>/json + https://itunes.apple.com/lookup", "charts": {}}
for cc in ("in", "us"):
    for g, gname in GENRES.items():
        feed = get(f"https://itunes.apple.com/{cc}/rss/topfreeapplications/limit=200/genre={g}/json")["feed"].get("entry", [])
        ids = [e["id"]["attributes"]["im:id"] for e in feed]
        look = {}
        for k in range(0, len(ids), 100):
            for a in get(f"https://itunes.apple.com/lookup?id={','.join(ids[k:k+100])}&country={cc}").get("results", []):
                look[str(a["trackId"])] = a
            time.sleep(2)
        rows = []
        for r, i in enumerate(ids, 1):
            a = look.get(i, {})
            rows.append({"rank": r, "id": int(i), "name": a.get("trackName") or feed[r-1]["im:name"]["label"], "seller": a.get("sellerName"),
                         "ratings": a.get("userRatingCount"), "primary_genre": a.get("primaryGenreName"), "genres": a.get("genres"),
                         "plane_word": bool(PLANE.search(a.get("trackName") or ""))})
        out["charts"][f"{cc}_{gname}"] = rows
        time.sleep(2)
json.dump(out, open(os.path.join(D, "charts.json"), "w"), indent=0, ensure_ascii=False)
for k, rows in out["charts"].items():
    print(f"== {k}: {len(rows)} entries, {sum(r['ratings'] is None for r in rows)} without lookup")
    for lo, hi in ((1, 25), (26, 50), (51, 100), (101, 150), (151, 200)):
        v = [r["ratings"] for r in rows if lo <= r["rank"] <= hi and r["ratings"] is not None]
        if v: print(f"  #{lo}-{hi}: n={len(v)} min={min(v):,} p25={int(statistics.quantiles(v, n=4)[0]) if len(v) > 1 else v[0]:,} median={int(statistics.median(v)):,} max={max(v):,}")
    for r in rows:
        if r["plane_word"]: print(f"    plane-ish #{r['rank']} {r['name']} | {r['seller']} | {r['ratings']}")
