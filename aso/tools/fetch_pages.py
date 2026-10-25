# Read-only: public apps.apple.com product pages -> subtitle + in-app purchase list per storefront.
# Output: aso/data/competitor_pages.json. Usage: python3 fetch_pages.py [id ...]
import json, os, re, sys, time, urllib.request
D = os.path.join(os.path.dirname(__file__), "..", "data")
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
GENRES = {"Action", "Adventure", "Arcade", "Board", "Card", "Casual", "Entertainment", "Family", "Racing", "Simulation",
          "Sports", "Strategy", "Education", "Puzzle", "Role Playing", "Games", "Music", "Trivia", "Word", "Casino"}
ids = sys.argv[1:] or [str(a["id"]) for a in json.load(open(os.path.join(D, "competitors.json")))]
out = {}
for i in ids:
    out[i] = {}
    for cc in ("in", "us"):
        url = f"https://apps.apple.com/{cc}/app/id{i}"
        try:
            t = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=30).read().decode("utf-8", "ignore")
            m = re.search(r'<script type="application/json" id="serialized-server-data">(.*?)</script>', t, re.S)
            data = json.loads(m.group(1))["data"][0]["data"]
            lk = data.get("lockup", {})
            sub = lk.get("subtitle")
            iap = []
            j = t.find('In-App Purchases","summary"')
            if j >= 0:
                seg = t[j:t.find('"shouldAlwaysPresentExpanded"', j)]
                iap = [[a, b.replace(" ", " ")] for a, b in re.findall(r'"leadingText":"([^"]*)","trailingText":"([^"]*)"', seg)]
            lang = re.search(r'"storefront":"%s","language":"([^"]+)"' % cc, t)
            out[i][cc] = {"url": url, "title": lk.get("title"), "subtitle": sub,
                          "subtitle_is_genre_fallback": sub in GENRES, "iap": iap, "page_language": lang and lang.group(1)}
        except Exception as e:
            out[i][cc] = {"url": url, "error": str(e)[:200]}
        print(i, cc, out[i][cc].get("title"), "|", out[i][cc].get("subtitle"), "|", len(out[i][cc].get("iap", [])), "IAP", out[i][cc].get("error", ""), flush=True)
        time.sleep(1.5)
P = os.path.join(D, "competitor_pages.json")
prev = json.load(open(P)) if os.path.exists(P) else {}
prev.update(out); prev["_fetched"] = time.strftime("%Y-%m-%d %H:%M %Z")
json.dump({**prev}, open(P, "w"), indent=1, ensure_ascii=False)
