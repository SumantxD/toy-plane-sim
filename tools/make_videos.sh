#!/bin/bash
# App Review demo + App Store app previews, recorded from the real game (Movie Maker, tools/videos.gd).
#   tools/make_videos.sh [review] [preview1] [preview2]     (no args: all three)
# Writes ../builds/appstore/video/{review_demo,preview_1_dogfight,preview_2_worlds_multiplayer}.mp4.
# Needs ffmpeg and python3 with Pillow (caption strips). Your settings and test-store file are put back after.
# LOGS=dir keeps the driver logs (CAP/MARK lines).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
OUT=../builds/appstore/video
TMP=$(mktemp -d)
USERDIR="$HOME/Library/Application Support/Godot/app_userdata/Toy Plane Arcade"
PIDS=()
PORT=7791 # LAN games on localhost, clear of a game or test already on the default port
mkdir -p "$OUT"
[ "$(df -k "$OUT" | awk 'NR==2 {print $4}')" -gt 5000000 ] || { echo "need 5 GB free for the raw recordings"; exit 1; }
echo "work dir: $TMP"
cp -p "$USERDIR/settings.cfg" "$TMP/settings.bak" 2>/dev/null || true
cp -p "$USERDIR/fake_store.cfg" "$TMP/fake_store.bak" 2>/dev/null || true

cleanup() {
	for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
	rm -f override.cfg
	if [ -f "$TMP/settings.bak" ]; then cp -p "$TMP/settings.bak" "$USERDIR/settings.cfg"; else rm -f "$USERDIR/settings.cfg"; fi
	if [ -f "$TMP/fake_store.bak" ]; then cp -p "$TMP/fake_store.bak" "$USERDIR/fake_store.cfg"; else rm -f "$USERDIR/fake_store.cfg"; fi
	rm -rf "$TMP"
}
trap cleanup EXIT

# rec NAME W H MODE: start a recording in the background (offscreen window); sets PID.
# Movie Maker takes its size from the window override, so override.cfg exists only while Godot starts.
rec() {
	printf '[display]\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\n' "$2" "$3" > override.cfg
	"$GODOT" --path . --position 6000,6000 --write-movie "$TMP/$1.avi" --fixed-fps 30 --max-fps 30 \
		-s tools/videos.gd -- --phone --fake-store --port $PORT "$4" > "$TMP/$1.log" 2>&1 &
	PID=$!
	PIDS+=("$PID")
	sleep 4
	rm -f override.cfg
}

wait_for() { # LOG TEXT
	until grep -q "$2" "$1"; do sleep 0.5; done
}

frames() { ffprobe -v error -count_packets -select_streams v:0 -show_entries stream=nb_read_packets -of csv=p=0 "$1"; }
mark() { grep "^MARK [0-9]* $2\$" "$1" | sed -n "${3:-1}p" | cut -d' ' -f2; }

TV="scale=in_range=full:out_range=tv,format=yuv420p" # Movie Maker's MJPEG is full range
ENC_V=(-c:v libx264 -profile:v high -pix_fmt yuv420p -preset slow -crf 18 -r 30)
ENC_A=(-c:a aac -b:a 256k -ar 48000 -ac 2)

# Caption strip (W x 80) from "CAP <frame> <text>" lines: PNGs + a concat list, frame -> seconds at 30 fps.
strip() { # OUTLIST W SECONDS LOG[:SHIFT_FRAMES]...
	python3 - "$@" <<'EOF'
import sys, os
from PIL import Image, ImageDraw, ImageFont
out, w, total = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
caps = []
for spec in sys.argv[4:]:
	log, _, shift = spec.partition(":")
	for line in open(log, errors="ignore"):
		if line.startswith("CAP "):
			_, f, text = line.rstrip("\n").split(" ", 2)
			caps.append(((int(f) + int(shift or 0)) / 30.0, text))
caps.sort()
d = os.path.dirname(out)
tag = os.path.splitext(os.path.basename(out))[0]
def card(i, text):
	img = Image.new("RGB", (w, 80), (11, 16, 32))
	g = ImageDraw.Draw(img)
	g.rectangle([0, 0, w, 3], fill=(255, 196, 64))
	size = 28
	font = ImageFont.truetype("assets/ui/kenney_future_narrow.ttf", size)
	while g.textlength(text, font=font) > w - 40:
		size -= 1
		font = ImageFont.truetype("assets/ui/kenney_future_narrow.ttf", size)
	tw = g.textlength(text, font=font)
	g.text(((w - tw) / 2, 41 - size / 2), text, font=font, fill=(255, 211, 77) if text[:2].rstrip(".").isdigit() else (240, 244, 255))
	p = os.path.join(d, "%s_%03d.png" % (tag, i))
	img.save(p)
	return p
rows = [(0.0, "")] + caps
with open(out, "w") as f:
	for i, (t, text) in enumerate(rows):
		end = rows[i + 1][0] if i + 1 < len(rows) else total
		if end - t > 0.001:
			p = card(i, text)
			f.write("file '%s'\nduration %.4f\n" % (p, end - t))
	f.write("file '%s'\n" % p)
EOF
}

review() {
	rec review 1280 720 review
	wait "$PID"
	local n; n=$(frames "$TMP/review.avi")
	strip "$TMP/strip1.txt" 1280 "$(echo "$n/30" | bc -l)" "$TMP/review.log"
	# multiplayer: two devices side by side, aligned on the match start
	rec host 960 540 host
	local hpid=$PID
	rec join 960 540 join
	wait "$hpid" "$PID"
	local hs js d hn
	hs=$(mark "$TMP/host.log" sync); js=$(mark "$TMP/join.log" sync)
	d=$((hs - js)) # B started later: it waits on its first frame until A catches up
	[ "$d" -ge 0 ] || { echo "join synced before host?"; exit 1; }
	hn=$(frames "$TMP/host.avi")
	local lost; lost=$(mark "$TMP/join.log" lost)
	[ -z "$lost" ] || [ $((lost + d - 15)) -ge "$hn" ] || hn=$((lost + d - 15)) # end before B drops out
	strip "$TMP/strip2.txt" 1280 "$(echo "$hn/30" | bc -l)" "$TMP/host.log" "$TMP/join.log:$d"
	python3 - "$TMP/labels.png" <<'EOF'
import sys
from PIL import Image, ImageDraw, ImageFont
img = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
g = ImageDraw.Draw(img)
big = ImageFont.truetype("assets/ui/kenney_future.ttf", 30)
for x, text in [(320, "DEVICE A  -  HOSTS"), (960, "DEVICE B  -  JOINS")]:
	g.text((x - g.textlength(text, font=big) / 2, 120), text, font=big, fill=(255, 211, 77))
for i, text in enumerate(["LAN play: both devices on the same Wi-Fi (here, two copies on one Mac).",
		"Online play: HOST ONLINE shows a 5-character room code; friends type it under JOIN A FRIEND."]):
	size = 24
	while g.textlength(text, font=ImageFont.truetype("assets/ui/kenney_future_narrow.ttf", size)) > 1220:
		size -= 1
	small = ImageFont.truetype("assets/ui/kenney_future_narrow.ttf", size)
	g.text((640 - g.textlength(text, font=small) / 2, 572 + i * 40), text, font=small, fill=(225, 232, 250))
img.save(sys.argv[1])
EOF
	ffmpeg -v error -y -i "$TMP/review.avi" -f concat -safe 0 -i "$TMP/strip1.txt" \
		-i "$TMP/host.avi" -i "$TMP/join.avi" -f concat -safe 0 -i "$TMP/strip2.txt" -loop 1 -i "$TMP/labels.png" \
		-filter_complex "\
[1:v]fps=30,format=yuv420p,trim=end_frame=$n[s1];[0:v]$TV[g1];[g1][s1]vstack,setsar=1[p1];\
[3:v]$TV,tpad=start=$d:start_mode=clone,trim=end_frame=$hn[b];[2:v]$TV[a2];[a2][b]hstack,scale=1280:360,pad=1280:720:0:180[mp];\
[mp][5:v]overlay=shortest=1[mpl];[4:v]fps=30,format=yuv420p,trim=end_frame=$hn[s2];[mpl][s2]vstack,setsar=1,trim=end_frame=$hn[p2];\
[2:a]atrim=end=$(echo "$hn/30" | bc -l)[ha];[p1][0:a][p2][ha]concat=n=2:v=1:a=1[v][a]" \
		-map "[v]" -map "[a]" "${ENC_V[@]}" "${ENC_A[@]}" -movflags +faststart "$OUT/review_demo.mp4"
	rm -f "$TMP"/review.avi "$TMP"/host.avi "$TMP"/join.avi
}

preview1() {
	rec preview1 1920 886 preview1
	wait "$PID"
	local a b
	a=$(mark "$TMP/preview1.log" in); b=$(mark "$TMP/preview1.log" out)
	a=$((b - a > 870 ? b - 870 : a)) # at most 29 s, ending on the taunt
	ffmpeg -v error -y -i "$TMP/preview1.avi" -filter_complex \
		"[0:v]trim=start_frame=$a:end_frame=$b,setpts=PTS-STARTPTS,setsar=1,$TV[v];[0:a]atrim=$(echo "$a/30" | bc -l):$(echo "$b/30" | bc -l),asetpts=PTS-STARTPTS[a]" \
		-map "[v]" -map "[a]" "${ENC_V[@]}" "${ENC_A[@]}" -movflags +faststart "$OUT/preview_1_dogfight.mp4"
	rm -f "$TMP/preview1.avi"
}

preview2() {
	rec preview2 1920 886 preview2
	local hpid=$PID
	wait_for "$TMP/preview2.log" HOSTING
	for i in 1 2; do
		"$GODOT" --headless --path . -- --join --bot --port $PORT > "$TMP/bot$i.log" 2>&1 &
		PIDS+=("$!")
	done
	wait "$hpid"
	local ins outs f="" n=0
	ins=($(grep "^MARK [0-9]* in$" "$TMP/preview2.log" | cut -d' ' -f2))
	outs=($(grep "^MARK [0-9]* out$" "$TMP/preview2.log" | cut -d' ' -f2))
	for i in "${!ins[@]}"; do
		f+="[0:v]trim=start_frame=${ins[$i]}:end_frame=${outs[$i]},setpts=PTS-STARTPTS,setsar=1[v$i];"
		f+="[0:a]atrim=$(echo "${ins[$i]}/30" | bc -l):$(echo "${outs[$i]}/30" | bc -l),asetpts=PTS-STARTPTS,afade=t=in:d=0.05[a$i];"
		n=$((n + 1))
	done
	for i in "${!ins[@]}"; do f+="[v$i][a$i]"; done
	f+="concat=n=$n:v=1:a=1[c][a];[c]$TV[v]"
	ffmpeg -v error -y -i "$TMP/preview2.avi" -filter_complex "$f" -map "[v]" -map "[a]" -t 29.9 \
		"${ENC_V[@]}" "${ENC_A[@]}" -movflags +faststart "$OUT/preview_2_worlds_multiplayer.mp4"
	rm -f "$TMP/preview2.avi"
}

for job in "${@:-review preview1 preview2}"; do
	for j in $job; do
		echo "== $j"
		$j
		[ -n "${LOGS:-}" ] && cp "$TMP"/*.log "$LOGS/" 2>/dev/null || true
	done
done
