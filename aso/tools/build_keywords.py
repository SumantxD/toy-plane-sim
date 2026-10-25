# Merge raw hints + search + judgement into aso/data/keywords.json and print a markdown table.
import json, os, re, statistics, sys
D = os.path.join(os.path.dirname(__file__), "..", "data")
sys.path.insert(0, os.path.dirname(__file__))
from kw_terms import TERMS
from kw_judgement import J
H = json.load(open(os.path.join(D, "raw_hints.json")))
S = json.load(open(os.path.join(D, "raw_search.json")))
# subtitles: subtitles.json (every top-10 game, tools/fetch_subtitles.py), then competitor_pages.json; genre fallbacks are not real subtitles
SUB = {"in": {}, "us": {}}
P = json.load(open(os.path.join(D, "competitor_pages.json")))
for k, v in P.items():
    if not k.startswith("_"):
        for cc in SUB: SUB[cc][k] = None if v.get(cc, {}).get("subtitle_is_genre_fallback") else v.get(cc, {}).get("subtitle")
if os.path.exists(os.path.join(D, "subtitles.json")):
    for cc, m in json.load(open(os.path.join(D, "subtitles.json"))).items():
        if cc in SUB: SUB[cc].update({k: x for k, x in m.items() if x})
GENRE_NAMES = {"Action", "Adventure", "Arcade", "Board", "Card", "Casual", "Family", "Racing", "Simulation", "Sports", "Strategy", "Puzzle", "Role Playing", "Games", "Music", "Trivia", "Word", "Casino", "Entertainment", "Education"}
GENERIC = {"game", "games", "3d", "with", "the", "for", "गेम"}  # same as fetch_search.py
has = lambda w, x: (re.search(r"\b" + re.escape(w.rstrip("s") if len(w) > 4 else w) + r"(s|es)?\b", x) is not None) if w.isascii() else w in x
def sub_hit(t, a, cc):
    sub = SUB[cc].get(str(a["id"]))
    if not sub or sub in GENRE_NAMES: return False
    words = t.lower().split(); content = [w for w in words if w not in GENERIC] or words
    return any(has(w, sub.lower()) for w in content)
def demand(h, t):
    sp = h.get("shortest_prefix"); full = h["full_term_hints"]
    ext = [x for x in full if isinstance(full, list) and x.startswith(t) and x != t]
    if sp and sp["prefix"] != t:
        first = len(t.split(" ")[0])
        return (3 if sp["chars"] <= first + 2 else 2), ext
    if sp or h["exact_in_full_hints_pos"]: return 1, ext
    return (1 if ext else 0), ext
def comp(s, t, cc):
    # competition = top-10 results that are Games AND match the term (content word in title or subtitle, or all content words in description)
    if "error" in s: return None, None, [], None
    rel = [a for a in s["top25"][:10] if a["game"] and (a["title_hit"] or a["desc_all"] or sub_hit(t, a, cc))]
    m = statistics.median([a["ratings"] for a in rel[:5]]) if rel else 0
    b = 0 if m < 1000 else 1 if m < 10000 else 2 if m < 100000 else 3
    raw5 = statistics.median([a["userRatingCount"] for a in s["top5"]]) if s.get("top5") else 0
    return m, b, rel, raw5
def tiebreak(h):
    # within a tier the demand score saturates at 3; shorter prefix + higher hint position = stronger. Lower is better.
    sp = h["shortest_prefix"]
    return sp["chars"] + sp["position"] if sp else None
def mismatch(s):
    # intent mismatch: Games are under 25% of results in a storefront with >= 20 results
    return s.get("resultCount", 0) >= 20 and s["games_in_results"] / s["resultCount"] < 0.25
CB = ["low", "medium", "high", "very high"]
rows = []
for g, t in TERMS:
    rel, why, conv, cnote = J[t]
    r = {"term": t, "group": g, "relevance": rel, "relevance_reason": why, "conversion_fit": conv, "conversion_note": cnote}
    for cc in ("in", "us"):
        h = H["data"][t][cc]; s = S["data"][t][cc]
        d, ext = demand(h, t); m, b, rg, raw5 = comp(s, t, cc)
        sp = h["shortest_prefix"]
        r[cc] = {"demand_proxy_score": d, "shortest_prefix": sp and sp["prefix"], "hint_position": sp and sp["position"],
                 "hint_list_at_shortest_prefix": sp and sp["hints"], "full_term_hints": h["full_term_hints"], "extensions": ext,
                 "resultCount": s.get("resultCount"), "games_in_results": s.get("games_in_results"),
                 "titles_with_all_words": s.get("title_contains_all_words"), "top5": s.get("top5"),
                 "relevant_games_top10": len(rg), "relevant_games_top5_names": [a["name"] for a in rg[:5]],
                 "relevant_games_median_ratings": m, "raw_top5_median_ratings": raw5, "tiebreak": tiebreak(h),
                 "relevant_games_subtitle_only": [a["name"] for a in rg if not (a["title_hit"] or a["desc_all"])], "competition_bucket": b is not None and CB[b], "_b": b,
                 "intent_mismatch": mismatch(s),
                 # top-of-list strength: the median above hides a big #1 (e.g. IN 'dogfight': median 34, #1 Metalstorm 1,940)
                 "top3_matching_max_ratings": max((a["ratings"] for a in rg[:3]), default=None),
                 "first_matching_under_1k_rank": next((i for i, a in enumerate(s.get("top25", []), 1) if a in rg and a["ratings"] < 1000), None)}
    if rel <= 2: pr, score, r["flags"] = "Avoid", None, []
    else:
        score = rel * 3 + conv + r["in"]["demand_proxy_score"] * 2 + r["us"]["demand_proxy_score"] - (r["in"]["_b"] or 0) - (r["us"]["_b"] or 0) * 0.5
        pr = "P1" if score >= 22 else "P2" if score >= 17 else "P3"
        flags = []
        if r["in"]["demand_proxy_score"] == 0 and r["us"]["demand_proxy_score"] == 0: flags.append("no hint signal: capped at P3")
        if r["in"]["intent_mismatch"] or r["us"]["intent_mismatch"]: flags.append("intent mismatch: capped at P3")
        if flags: pr = "P3"
        r["flags"] = flags
    r["priority_score"] = score; r["priority"] = pr
    for cc in ("in", "us"): r[cc].pop("_b")
    rows.append(r)
TIER = {"P1": 0, "P2": 1, "P3": 2, "Avoid": 3}
TB = lambda x: 99 if x is None else x
rows.sort(key=lambda r: (TIER[r["priority"]], -(r["priority_score"] or 0), TB(r["in"]["tiebreak"]), TB(r["us"]["tiebreak"]), -r["relevance"]))
json.dump({"generated_from": ["raw_hints.json", "raw_search.json", "tools/kw_judgement.py"],
           "hints_fetched": H["fetched"], "search_fetched": S["fetched"],
           "labels": {"demand_proxy_score": "MEASURED autocomplete presence (0-3), a DEMAND PROXY, not volume",
                      "relevant_games_median_ratings": "MEASURED iTunes Search API: median userRatingCount of the first 5 top-10 results that are Games and match the term in title, subtitle (subtitles.json / competitor_pages.json) or description",
                      "raw_top5_median_ratings": "MEASURED iTunes Search API: median userRatingCount of the raw top 5, no filter",
                      "tiebreak": "MEASURED hints: characters of the shortest prefix + hint position; lower is stronger; null = no hint",
                      "relevance": "judgement vs code (VERIFIED refs in reason)", "conversion_fit": "HYPOTHESIS",
                      "priority": "formula in keyword-research.md"},
           "keywords": rows}, open(os.path.join(D, "keywords.json"), "w"), indent=1, ensure_ascii=False)
def f(n): return "err" if n is None else f"{int(n):,}"
for i, r in enumerate(rows, 1):
    I, U = r["in"], r["us"]
    hp = lambda x: f'{x["demand_proxy_score"]} (`{x["shortest_prefix"]}` #{x["hint_position"]})' if x["shortest_prefix"] else f'{x["demand_proxy_score"]}' + (f' (ext: {", ".join(x["extensions"][:2])})' if x["extensions"] else "")
    cp = lambda x: f'{x["games_in_results"]}/{x["resultCount"]} g, {x["titles_with_all_words"]} aw, {x["relevant_games_top10"]} rel: {f(x["relevant_games_median_ratings"])} ({x["competition_bucket"]}); raw5 {f(x["raw_top5_median_ratings"])}'
    tb = lambda x: "-" if x["tiebreak"] is None else str(x["tiebreak"])
    print(f'| {i} | {r["term"]} | {r["group"]} | {hp(I)} | {hp(U)} | {cp(I)} | {cp(U)} | {tb(I)} / {tb(U)} | {r["relevance"]} | {r["conversion_fit"]} | {r["priority_score"] if r["priority_score"] is not None else "-"} | {r["priority"]}{" ¹" if any("hint" in x for x in r["flags"]) else ""}{" ²" if any("mismatch" in x for x in r["flags"]) else ""} |')
