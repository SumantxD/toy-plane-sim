# Customer reviews RSS with retries and URL variants. Saves aso/data/reviews/<id>_<cc>[_p<page>].json only if entries came back.
# Usage: python3 fetch_reviews.py ID:CC[:PAGE] ...
import json, os, sys, time, urllib.request
D = os.path.join(os.path.dirname(__file__), "..", "data", "reviews")
VARIANTS = ["https://itunes.apple.com/{cc}/rss/customerreviews/page={p}/id={id}/sortby=mostrecent/json",
            "https://itunes.apple.com/{cc}/rss/customerreviews/id={id}/sortby=mostrecent/page={p}/json",
            "https://itunes.apple.com/{cc}/rss/customerreviews/page={p}/id={id}/json"]
for arg in sys.argv[1:]:
    i, cc, p = (arg.split(":") + ["1"])[:3]
    got, log = None, []
    for attempt in range(3):
        for v in VARIANTS:
            u = v.format(cc=cc, id=i, p=p)
            try:
                d = json.loads(urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"}), timeout=30).read())
                e = d.get("feed", {}).get("entry", [])
                e = [e] if isinstance(e, dict) else e
                n = sum("im:rating" in x for x in e)
                log.append(f"{u} -> {n}")
                if n:
                    got = d; break
            except Exception as ex:
                log.append(f"{u} -> {str(ex)[:80]}")
            time.sleep(2)
        if got: break
        time.sleep(8 * (attempt + 1))
    name = f"{i}_{cc}" + ("" if p == "1" else f"_p{p}") + ".json"
    if got:
        json.dump(got, open(os.path.join(D, name), "w"))
    print(arg, "OK" if got else "EMPTY", f"({len(log)} requests)", log[-1], flush=True)
