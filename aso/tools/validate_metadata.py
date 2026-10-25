#!/usr/bin/env python3
"""Validate App Store listing fields against Apple's limits and metadata rules.

Usage: python3 validate_metadata.py LISTING.json [--banned FILE] [--competitors FILE]
Rules and sources: aso/apple-requirements.md. Exit code 1 if any field FAILs.
"""
import json, re, sys, argparse
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "data"

# field: (max chars, required, min chars)
LIMITS = {
    "name": (30, True, 2),
    "subtitle": (30, False, 0),
    "promotional_text": (170, False, 0),
    "description": (4000, True, 1),
    "whats_new": (4000, False, 0),
}
KEYWORDS_MAX = 100  # ASC help says 100 bytes; apple.com/app-store/search says 100 characters. Check both.
FILLER = {"the", "to", "a", "an", "and", "of", "for", "in", "on", "with", "by", "or", "my", "your"}
GENERIC = {"app", "apps", "game", "games"}
PRICE = re.compile(r"[$₹€£]\s*\d|\b\d+\s*(rs|inr|usd)\b|\bfree\b|\bsale\b|\b\d+\s*% off\b", re.I)
CLAIMS = re.compile(r"#\s*1\b|\bno\.?\s*1\b|\bnumber one\b|\bbest\b|\btop[- ]rated\b|\bworld['’]s\b", re.I)
MODE_NAMES = re.compile(r"\bfree flight\b", re.I)  # in-game mode name (main.gd:10), not a price claim
# locale -> spellings that belong to the other English (prefix match: colour -> colours). Keywords are exempt.
WRONG_SPELLING = {
    "en-US": ["armour", "colour", "tyre", "defence", "centre", "favourite", "aeroplane"],
    "en-GB": ["armor", "color", "defense", "center", "favorite"],
}
CORP = re.compile(r"[\s,]+(pte\.?|ltd\.?|limited|inc\.?|llc|gmbh|s\.?l\.?|s\.?a\.?|co\.?|corp\.?|private|pvt\.?|ab|oy|as)\b\.?", re.I)


def words(s):
    return [w for w in re.split(r"[^\w\u0300-\u036f\u0900-\u0dff']+", s.lower()) if w.strip("'")]


def stem(w):
    # ponytail: naive plural folding (s/es/ies); Apple's own matcher is unpublished.
    if len(w) > 4 and w.endswith("ies"):
        return w[:-3] + "y"
    if len(w) > 3 and w.endswith("es") and w[-3] in "sxz":
        return w[:-2]
    if len(w) > 3 and w.endswith("s") and not w.endswith("ss"):
        return w[:-1]
    return w


def load_banned(path):
    """Lines: term | severity(fail|warn) | reason | fields (optional, space-separated; default all). '#' comments."""
    out = []
    if path and Path(path).exists():
        for line in Path(path).read_text(encoding="utf-8").splitlines():
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split("|")]
            out.append((parts[0].lower(), (parts[1] if len(parts) > 1 and parts[1] else "fail").lower(),
                        parts[2] if len(parts) > 2 else "banned term",
                        set(parts[3].split()) if len(parts) > 3 and parts[3] else None))
    return out


def load_competitors(path):
    """(brands and sellers, title words after the brand, e.g. 'air war' from 'Alliance: Air War')."""
    out, titles = set(), set()
    if path and Path(path).exists():
        for app in json.loads(Path(path).read_text(encoding="utf-8")):
            brand, *rest = re.split(r"\s*[:|–—-]\s+|\s+[–—-]\s*", re.sub(r"[®™©]", "", app.get("name", "")))
            brand = brand.strip()
            if len(brand) > 3:
                out.add(brand.lower())
            titles |= {t.strip().lower() for t in rest if len(t.strip()) > 3}
            seller = CORP.sub("", app.get("seller", "")).strip(" ,.")
            if len(seller) > 3:
                out.add(seller.lower())
    return sorted(out), sorted(titles)


def has_phrase(text, phrase):
    return re.search(r"(?<![^\W_])" + re.escape(phrase) + r"(?![^\W_])", text, re.I) is not None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("listing")
    ap.add_argument("--banned", default=str(DATA / "banned_terms.txt"))
    ap.add_argument("--competitors", default=str(DATA / "competitors.json"))
    a = ap.parse_args()

    L = json.loads(Path(a.listing).read_text(encoding="utf-8"))
    banned = load_banned(a.banned)
    competitors, comp_titles = load_competitors(a.competitors)
    own = {w for w in words(L.get("name", "") + " " + L.get("developer_name", ""))}
    results = []  # (field, status, msgs)

    def check_terms(field, text, msgs, status):
        flat = text.replace(",", " ")
        for term, sev, why, fields in banned:
            if (fields is None or field in fields) and has_phrase(flat, term):
                msgs.append(f"{'banned' if sev == 'fail' else 'risky'} term '{term}': {why}")
                status = "FAIL" if sev == "fail" else max_status(status, "WARN")
        for c in competitors:
            if has_phrase(flat, c) and not set(words(c)) <= own:
                msgs.append(f"matches competitor app/company name '{c}': remove unless it is a plain generic phrase (Guideline 2.3.7)")
                status = max_status(status, "WARN")
        if field in ("name", "subtitle"):
            for t in comp_titles:
                if has_phrase(flat, t):
                    msgs.append(f"copies competitor title words '{t}': reads as a knock-off of that app (Guideline 2.3.7, 4.1)")
                    status = max_status(status, "WARN")
        return status

    for field, (mx, required, mn) in LIMITS.items():
        text = L.get(field, "") or ""
        msgs, status = [], "PASS"
        n, b = len(text), len(text.encode("utf-8"))
        if not text.strip():
            results.append((field, "FAIL" if required else "SKIP", ["required, missing"] if required else ["empty (optional)"]))
            continue
        if n > mx:
            status = "FAIL"; msgs.append(f"{n} chars > {mx}")
        if n < mn:
            status = "FAIL"; msgs.append(f"{n} chars < min {mn}")
        if text != text.strip():
            status = max_status(status, "WARN"); msgs.append("leading/trailing whitespace")
        if field == "description" and re.search(r"<[a-z/][^>]*>", text, re.I):
            status = "FAIL"; msgs.append("HTML not supported, plain text only")
        if field in ("name", "subtitle"):
            if PRICE.search(text):
                status = "FAIL"; msgs.append("pricing info in name/subtitle (Guideline 2.3.7)")
            if CLAIMS.search(text):
                status = max_status(status, "WARN"); msgs.append("unverifiable claim/superlative (Guideline 2.3.7)")
        if field in ("description", "promotional_text") and PRICE.search(MODE_NAMES.sub("", text)):
            status = max_status(status, "WARN"); msgs.append(f"price/sale wording; Apple advises no specific prices in {field}")
        if field == "promotional_text" and CLAIMS.search(text):
            status = max_status(status, "WARN"); msgs.append("unverifiable claim/superlative (Guideline 2.3.7)")
        status = check_terms(field, text, msgs, status)
        wrong = sorted({m.group(0).lower() for w in WRONG_SPELLING.get(L.get("locale", ""), [])
                        for m in re.finditer(r"\b" + w + r"\w*", text, re.I)})
        if wrong:
            status = max_status(status, "WARN"); msgs.append(f"spelling from the other English for locale {L['locale']}: {', '.join(wrong)}")
        msgs.insert(0, f"{n}/{mx} chars, {b} bytes")
        results.append((field, status, msgs))

    # name vs subtitle duplicates
    nw, sw = {stem(w) for w in words(L.get("name", ""))}, {stem(w) for w in words(L.get("subtitle", ""))}
    dup_ns = sorted((nw & sw) - FILLER)
    if dup_ns:
        results.append(("name+subtitle", "WARN", [f"repeated words waste indexed space: {', '.join(dup_ns)}"]))
    else:
        results.append(("name+subtitle", "PASS", ["no repeated words"]))

    kw = L.get("keywords", "") or ""
    msgs, status = [], "PASS"
    if not kw.strip():
        results.append(("keywords", "FAIL", ["required, missing"]))
    else:
        n, b = len(kw), len(kw.encode("utf-8"))
        msgs.append(f"{n}/{KEYWORDS_MAX} chars, {b}/{KEYWORDS_MAX} UTF-8 bytes")
        if b > KEYWORDS_MAX:
            status = "FAIL"; msgs.append(f"{b} bytes > {KEYWORDS_MAX} (ASC help: up to 100 bytes)")
        if n > KEYWORDS_MAX:
            status = "FAIL"; msgs.append(f"{n} chars > {KEYWORDS_MAX}")
        if re.search(r",\s|\s,", kw):
            status = max_status(status, "WARN"); msgs.append("spaces around commas waste bytes")
        if ";" in kw or "\n" in kw:
            status = "FAIL"; msgs.append("separator must be comma")
        terms = [t.strip() for t in kw.split(",")]
        if any(not t for t in terms):
            status = max_status(status, "WARN"); msgs.append("empty term (double or trailing comma)")
        terms = [t for t in terms if t]
        short = [t for t in terms if len(t) <= 2]
        if short:
            status = "FAIL"; msgs.append(f"terms must be > 2 chars (ASC help): {', '.join(short)}")
        seen, dups = {}, set()
        for t in terms:
            for w in words(t):
                s = stem(w)
                if s in seen:
                    dups.add(w)
                seen.setdefault(s, w)
        if dups:
            status = max_status(status, "WARN"); msgs.append(f"duplicate/plural words inside keywords: {', '.join(sorted(dups))}")
        kws = {stem(w) for t in terms for w in words(t)}
        overlap = sorted((kws & (nw | sw)) - FILLER)
        if overlap:
            status = max_status(status, "WARN"); msgs.append(f"words already in name/subtitle (already indexed): {', '.join(overlap)}")
        dev = {stem(w) for w in words(L.get("developer_name", ""))}
        if kws & dev:
            status = max_status(status, "WARN"); msgs.append(f"developer name words (already searchable): {', '.join(sorted(kws & dev))}")
        filler = sorted({w for t in terms for w in words(t)} & FILLER)
        if filler:
            status = max_status(status, "WARN"); msgs.append(f"filler words: {', '.join(filler)}")
        generic = sorted({w for t in terms for w in words(t)} & GENERIC)
        if generic:
            status = max_status(status, "WARN"); msgs.append(f"generic/category words: {', '.join(generic)}")
        if re.search(r"[#@]", kw):
            status = max_status(status, "WARN"); msgs.append("special characters # or @ carry no weight")
        if PRICE.search(kw):
            status = "FAIL"; msgs.append("pricing terms in keywords (Guideline 2.3.7)")
        status = check_terms("keywords", kw, msgs, status)
        results.append(("keywords", status, msgs))

    # App Review compares the store name with the name on the device (project.godot config/name).
    dev_name = re.search(r'^config/name="([^"]*)"', (HERE.parent.parent / "project.godot").read_text(encoding="utf-8"), re.M)
    if dev_name and L.get("name"):
        if L["name"].lower().startswith(dev_name.group(1).lower()):
            results.append(("device name", "PASS", [f"store name starts with project.godot name '{dev_name.group(1)}'"]))
        else:
            results.append(("device name", "WARN", [f"store name '{L['name']}' differs from project.godot config/name '{dev_name.group(1)}' (also export_presets.cfg, main menu, PRIVACY.md, SUPPORT.md): rename the game too or keep the store name close"]))

    w = max(len(r[0]) for r in results)
    for field, status, msgs in results:
        print(f"{status:<4}  {field:<{w}}  " + ("; ".join(msgs)))
    fails = sum(r[1] == "FAIL" for r in results)
    warns = sum(r[1] == "WARN" for r in results)
    print(f"\n{'FAIL' if fails else 'PASS'}: {fails} fail, {warns} warn, {len(competitors)} competitor names, {len(banned)} banned terms checked")
    sys.exit(1 if fails else 0)


def max_status(a, b):
    order = ["SKIP", "PASS", "WARN", "FAIL"]
    return a if order.index(a) >= order.index(b) else b


if __name__ == "__main__":
    main()
