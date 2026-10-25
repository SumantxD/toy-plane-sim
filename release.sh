#!/bin/sh
# Builds ../builds/ToyPlaneArcade-vX-{mac,windows}.zip (game + HOW_TO_PLAY + licenses). Bump VERSION in main.gd,
# config/version in project.godot and the versions in export_presets.cfg first.
set -e
cd "$(dirname "$0")"
V=$(grep 'const VERSION' main.gd | cut -d'"' -f2)
B=../builds
rm -rf /tmp/out && mkdir -p /tmp/out/mac /tmp/out/win
godot --headless -s tools/make_licenses.gd
godot --headless --export-release "macOS"
godot --headless --export-release "Windows"
cd /tmp/out
mkdir -p "macpkg/Toy Plane Arcade" "winpkg/Toy Plane Arcade"
unzip -q mac/ToyPlaneSim-mac.zip -d "macpkg/Toy Plane Arcade"
for d in macpkg winpkg; do cp "$OLDPWD/$B/HOW_TO_PLAY.txt" "$OLDPWD/THIRD_PARTY_LICENSES.txt" "$d/Toy Plane Arcade/"; done
cp win/* "winpkg/Toy Plane Arcade/"
codesign -v "macpkg/Toy Plane Arcade/Toy Plane Arcade.app"
(cd macpkg && ditto -c -k --keepParent "Toy Plane Arcade" "../ToyPlaneArcade-v$V-mac.zip")
(cd winpkg && zip -q -r "../ToyPlaneArcade-v$V-windows.zip" "Toy Plane Arcade")
mv "ToyPlaneArcade-v$V-mac.zip" "ToyPlaneArcade-v$V-windows.zip" "$OLDPWD/$B/"
echo "built v$V into $B"
