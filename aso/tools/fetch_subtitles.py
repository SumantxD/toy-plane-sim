# Read-only: subtitle of every Game in the top 10 of each raw_search.json query that the title/description rule
# did not already match (the only ones a subtitle can add), per storefront, from apps.apple.com.
# Output: aso/data/subtitles.json {"in": {id: subtitle|null}, "us": {...}}. Resumable: skips ids already fetched.
import json, os, re, time, urllib.request
D = os.path.join(os.path.dirname(__file__), "..", "data")
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
OUT = os.path.join(D, "subtitles.json")
S = json.load(open(os.path.join(D, "raw_search.json")))["data"]
out = json.load(open(OUT)) if os.path.exists(OUT) else {"in": {}, "us": {}}
for cc in ("in", "us"):
    ids = sorted({str(a["id"]) for v in S.values() for a in v[cc].get("top25", [])[:10] if a["game"] and not (a["title_hit"] or a["desc_all"])})
    for i in ids:
        if i in out[cc]: continue
        try:
            t = urllib.request.urlopen(urllib.request.Request(f"https://apps.apple.com/{cc}/app/id{i}", headers={"User-Agent": UA}), timeout=30).read().decode("utf-8", "ignore")
            m = re.search(r'<script type="application/json" id="serialized-server-data">(.*?)</script>', t, re.S)
            out[cc][i] = json.loads(m.group(1))["data"][0]["data"].get("lockup", {}).get("subtitle")
        except Exception as e:
            print(cc, i, "error", str(e)[:100], flush=True); time.sleep(5); continue
        json.dump({**out, "_fetched": time.strftime("%Y-%m-%d %H:%M %Z")}, open(OUT, "w"), indent=0, ensure_ascii=False)
        time.sleep(1.2)
    print(cc, len(out[cc]), "of", len(ids), flush=True)
