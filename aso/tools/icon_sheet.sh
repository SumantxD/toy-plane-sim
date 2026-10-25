#!/bin/sh
# Usage: aso/tools/icon_sheet.sh [A B C]. Renders the concepts, fetches competitor icons once (data/competitors.json and the
# top 3 iTunes Search results for "dogfight", country=in), downsizes everything with sips, builds contact_sheet.png and masked_1024.png.
set -e
P=$(cd "$(dirname "$0")/../.." && pwd)
I="$P/aso/creative/icons"
mkdir -p "$I/src/sizes" "$I/src/competitors"
godot --path "$P" --resolution 1024x1024 -s "$P/aso/tools/render_icons.gd" -- "$@"
cd "$P/aso" && python3 - <<'EOF'
import json, os, subprocess, time
urls = [c["icon"] for c in json.load(open("data/competitors.json"))]
urls += [r["artworkUrl512"] for r in json.load(open("data/search/dogfight_in.json"))["results"][:3]]
names = ["%02d" % i for i in range(20)] + ["search%d" % i for i in range(3)]
for n, u in zip(names, urls):
    f = "creative/icons/src/competitors/%s.jpg" % n
    if not os.path.exists(f):
        subprocess.run(["curl", "-sfL", "-o", f, u], check=True)
        time.sleep(0.4)
EOF
for n in A_hero B_duel C_face B_duel_dark B_duel_tinted current; do
  f="$I/$n.png"; [ "$n" = current ] && f="$P/assets/ui/icon_ios.png"
  for s in 1024 192 180 128 120 87 60 40 29; do sips -z $s $s "$f" --out "$I/src/sizes/${n}_$s.png" >/dev/null; done
done
for f in "$I"/src/competitors/*.jpg; do
  for s in 192 128 60; do sips -s format png -z $s $s "$f" --out "$I/src/sizes/c_$(basename "$f" .jpg)_$s.png" >/dev/null; done
done
godot --path "$P" --resolution 1760x1400 -s "$P/aso/tools/icon_sheet.gd"
