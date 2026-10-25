# Read-only: which INR prices appear in live IN In-App Purchase lists (apps.apple.com/in, max 10 shown per app).
# Sample: every app in data/charts.json IN charts + data/competitor_pages.json. Output: aso/data/in_price_points.json
import collections, json, os, re, time, urllib.request
D = os.path.join(os.path.dirname(__file__), "..", "data")
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
C = json.load(open(os.path.join(D, "charts.json")))["charts"]
ids = sorted({str(r["id"]) for k in ("in_Action", "in_Simulation") for r in C[k]})
seen = collections.defaultdict(list)
for i in ids:
    try:
        t = urllib.request.urlopen(urllib.request.Request(f"https://apps.apple.com/in/app/id{i}", headers={"User-Agent": UA}), timeout=30).read().decode("utf-8", "ignore")
    except Exception as e:
        print(i, "error", str(e)[:80], flush=True); time.sleep(5); continue
    j = t.find('In-App Purchases","summary"')
    if j >= 0:
        seg = t[j:t.find('"shouldAlwaysPresentExpanded"', j)]
        for name, price in re.findall(r'"leadingText":"([^"]*)","trailingText":"([^"]*)"', seg):
            seen[price.replace(" ", " ").replace(" ", "")].append(i)
    time.sleep(1.2)
P = json.load(open(os.path.join(D, "competitor_pages.json")))
for k, v in P.items():
    if k.startswith("_"): continue
    for name, price in v.get("in", {}).get("iap", []):
        seen[price.replace(" ", " ").replace(" ", "")].append(k)
out = {"fetched": time.strftime("%Y-%m-%d %H:%M %Z"), "apps_sampled": len(ids) + sum(1 for k in P if not k.startswith("_")),
       "prices": {p: {"items": len(v), "apps": len(set(v))} for p, v in sorted(seen.items(), key=lambda x: -len(x[1]))}}
json.dump(out, open(os.path.join(D, "in_price_points.json"), "w"), indent=0, ensure_ascii=False)
for p in ("₹79", "₹99", "₹199", "₹499"):
    print(p, out["prices"].get(p))
