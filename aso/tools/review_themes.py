# Theme counts over review feeds + precision from a hand-checked sample.
# python3 review_themes.py counts       -> aso/data/review_theme_counts.txt (page-1 feeds; IN page 2 counted separately)
# python3 review_themes.py sample N [themes] -> stratified sample of regex-matched reviews not yet hand-checked
# python3 review_themes.py precision [file] -> precision per theme (default aso/data/review_handcheck.csv = v2 regexes)
import csv, glob, json, os, random, re, sys
D = os.path.join(os.path.dirname(__file__), "..", "data")
THEMES = {
    # v2 (tightened after round-1 hand check, see review_handcheck_v1.csv): ads, p2w, connection, friends, fuel, no-ads
    "ads": r"\b(too many|so many|lots of|a lot of|full of|forced|every|constant|more|watch(ing)?|unskippable|so much|many|just|the) (\w+ )?(ads|adds|advertisements?)\b(?! (say|show|said|showed))|\b(ads|adds) (after|every|are|is|pop)|\bad after|ad (machine|platform)",
    "pay_to_win/grind": r"(?<!n't )(?<!not )(?<!seem )(pay.?to.?win|\bp2w\b)|paywall|money.?grab|cash.?grab|(have|need|forced) to (pay|buy|purchase)|(too|very|so|extremely) grindy|grind(ing)? (is|over)|have to grind",
    "crash/won't open": r"crash|won'?t (open|load|start)|does ?n[o']t (open|load|start)|not (opening|loading)|stuck|freez|black screen",
    "connection/server": r"disconnect|server|(connect(ion)?|connect to) (to )?(the )?internet|internet (connection|issue|error|problem)|network (error|issue|problem)|\blag(gy|s|ging)?\b|connection (error|issue|problem|lost)|can'?t connect|won'?t connect",
    "matchmaking/bots": r"matchmak|\bbots?\b|find(ing)? (a )?(match|game|players?|opponents?)|queue",
    "friends/private rooms": r"(play|playing|played|fight|battle|match|team|groups) (\w+ ){0,3}(with|against|vs\.?|of) (my |our |your |bigger groups of )?(friends|cousins)|private (room|match|lobb)|personal room|separate room|\blan\b|local (play|multiplayer|friends)|play local|invite (my )?friends",
    "fuel/energy timers": r"\bfuel\b(?!\s*(train|&|and|level|upgrade))|refuel|\benergy\b|\btimers?\b|cooldown|gas tank|wait(ing)? \d+ ?(min|hour|h\b)",
    "misleading store art/ads": r"mislead|nothing like|not like the|false advertis|fake ad|pictures are|screenshots? (are|is|show)",
    "more maps/modes": r"more (maps|modes|levels|planes|aircraft)|new (maps|modes)|add (a |more |new )?(mode|map)s?",
    "cockpit view": r"cockpit|first.?person",
    "no ads (praise)": r"(?<!were )(?<!was )(?<!bought )\bno (ads|adds|advert)|without ads|ad.?free",
    "fun/simple (praise)": r"\bfun\b|simple|addict|enjoy|\blove",
    "toxic chat/players": r"toxic|bad words|bull(y|ies)|harass|abus|swear",
}
NAMES = {a["id"]: a["name"].split(":")[0].split(" - ")[0] for a in json.load(open(os.path.join(D, "competitors.json")))}


def feeds(pages="1"):
    for f in sorted(glob.glob(os.path.join(D, "reviews", "*.json"))):
        b = os.path.basename(f)[:-5].split("_")
        page = b[2][1:] if len(b) > 2 else "1"
        if pages != "all" and page != pages:
            continue
        e = json.load(open(f)).get("feed", {}).get("entry", [])
        e = [x for x in ([e] if isinstance(e, dict) else e) if "im:rating" in x]
        yield int(b[0]), b[1], page, [{"key": x["id"]["label"], "stars": int(x["im:rating"]["label"]),
                                         "text": (x["title"]["label"] + ". " + x["content"]["label"])} for x in e]


def match(text):
    return [t for t, rx in THEMES.items() if re.search(rx, text, re.I)]


cmd = sys.argv[1] if len(sys.argv) > 1 else "counts"
if cmd == "counts":
    rows, tot = [], {t: 0 for t in THEMES}
    for page in ("1", "2"):
        for i, cc, p, rv in feeds(page):
            if not rv: continue
            c = {t: 0 for t in THEMES}
            for r in rv:
                for t in match(r["text"]): c[t] += 1
            if page == "1":
                for t in c: tot[t] += c[t]
            rows.append([NAMES.get(i, i), cc + ("" if p == "1" else f" p{p}"), len(rv), f'{sum(r["stars"] for r in rv) / len(rv):.2f}'] + list(c.values()))
    with open(os.path.join(D, "review_theme_counts.txt"), "w") as f:
        w = csv.writer(f); w.writerow(["app", "feed", "n_reviews", "avg_stars"] + list(THEMES)); w.writerows(rows)
        f.write("TOTAL page-1 feeds " + json.dumps(tot) + "\n")
    print(open(os.path.join(D, "review_theme_counts.txt")).read())
elif cmd == "sample":
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 50
    only = sys.argv[3].split(",") if len(sys.argv) > 3 else list(THEMES)
    done = {r["review_id"] for f in glob.glob(os.path.join(D, "review_handcheck*.csv")) for r in csv.DictReader(open(f))}
    pool = [(i, cc, r) for i, cc, p, rv in feeds("all") for r in rv if r["key"] not in done]
    random.seed(7)
    pick, per = {}, max(1, n // len(only))
    for t in only:
        m = [x for x in pool if t in match(x[2]["text"]) and x[2]["key"] not in pick]
        for x in random.sample(m, min(per, len(m))): pick[x[2]["key"]] = x
    rest = [x for x in pool if set(match(x[2]["text"])) & set(only) and x[2]["key"] not in pick]
    for x in random.sample(rest, max(0, n - len(pick))): pick[x[2]["key"]] = x
    for k, (i, cc, r) in pick.items():
        print(f'### {k} | {NAMES.get(i, i)} {cc} | {r["stars"]}* | regex: {"; ".join(match(r["text"]))}\n{r["text"][:600]}\n')
elif cmd == "precision":
    hits = {t: [0, 0] for t in THEMES}
    for row in csv.DictReader(open(os.path.join(D, sys.argv[2] if len(sys.argv) > 2 else "review_handcheck.csv"))):
        true = set(filter(None, row["true_themes"].split(";")))
        for t in filter(None, row["regex_themes"].split(";")):
            hits[t][1] += 1; hits[t][0] += t in true
    for t, (ok, n) in hits.items():
        print(f"{t:28} {ok}/{n} = {ok / n:.0%}" if n else f"{t:28} 0/0")
