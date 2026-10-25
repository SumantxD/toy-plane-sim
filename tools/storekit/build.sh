#!/bin/bash
# Rebuilds ios/plugins/godotstorekit/godotstorekit.{debug,release}.xcframework from src/.
# Source: github.com/araid80/godot-storekit v1.0.6 (MIT, see src/LICENSE).
#
#   tools/storekit/build.sh <godot-src> [scons]
#
# <godot-src>: Godot checkout at the engine's exact tag (4.7.2-stable) that has been built
# once for iOS (any target), so the *.gen.h headers exist.
#
# ObjC++ flags are taken verbatim from Godot's own iOS device compile db (template_debug /
# template_release), not the godot-ios-plugins harness: the harness omits THREADS_ENABLED,
# which changes Mutex/Object layout and breaks ABI.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/src"
OUT="$(cd "$HERE/../.." && pwd)/ios/plugins/godotstorekit"
GODOT="$(cd "${1:?usage: build.sh <godot-src> [scons]}" && pwd)"
SCONS="${2:-scons}"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SWIFT_TARGET="arm64-apple-ios15.0" # StoreKit 2 floor
REF="drivers/apple_embedded/app_delegate_service.mm"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

for kind in debug release; do
  echo "[$kind] compile db"
  ( cd "$GODOT" && "$SCONS" platform=ios arch=arm64 target=template_$kind \
      compiledb=yes compiledb_gen_only=yes >/dev/null )
  mv "$GODOT/compile_commands.json" "$WORK/cc-$kind.json"
  # Engine command for $REF minus output/source/depfile args, one arg per line.
  python3 - "$WORK/cc-$kind.json" "$REF" > "$WORK/flags-$kind" <<'EOF'
import json, shlex, sys
db, ref = sys.argv[1], sys.argv[2]
e = next(e for e in json.load(open(db)) if e["file"] == ref)
a = e.get("arguments") or shlex.split(e["command"])
out, skip = [], False
for x in a[1:]:
    if skip: skip = False; continue
    if x in ("-o", "-MT"): skip = True; continue
    if x in ("-c", "-MMD", ref): continue
    out.append(x)
assert "-DTHREADS_ENABLED" in out and "-DNDEBUG" in out
print(a[0]); print("\n".join(out))
EOF
  CXX="$(head -1 "$WORK/flags-$kind")"
  FLAGS=()
  while IFS= read -r f; do FLAGS+=("$f"); done < <(tail -n +2 "$WORK/flags-$kind")

  echo "[$kind] swift bridge"
  mkdir -p "$WORK/$kind"
  EXTRA=(-O); [ "$kind" = debug ] && EXTRA=(-Onone -g)
  swiftc -emit-library -static -emit-objc-header \
    -emit-objc-header-path "$WORK/$kind/GodotStoreKit-Swift.h" \
    -module-name GodotStoreKit -target "$SWIFT_TARGET" -sdk "$SDK" "${EXTRA[@]}" \
    -file-prefix-map "$SRC=/godotstorekit" -file-prefix-map "$WORK=/work" \
    -o "$WORK/$kind/swift.a" "$SRC/StoreKitBridge.swift"

  echo "[$kind] objc++"
  objs=()
  for mm in "$SRC"/*.mm; do
    o="$WORK/$kind/$(basename "$mm" .mm).o"
    # cwd = godot-src: the engine's -I paths are relative to it. Prefix maps only rewrite
    # __FILE__/debug paths; they do not affect ABI.
    ( cd "$GODOT" && "$CXX" -c "${FLAGS[@]}" -I"$WORK/$kind" \
        -ffile-prefix-map="$SRC=/godotstorekit" -ffile-prefix-map="$GODOT=/godot" \
        -ffile-prefix-map="$WORK=/work" -o "$o" "$mm" )
    objs+=("$o")
  done

  echo "[$kind] merge + strip"
  libtool -static -o "$WORK/$kind/libgodotstorekit.a" "${objs[@]}" "$WORK/$kind/swift.a" 2>/dev/null
  strip -S "$WORK/$kind/libgodotstorekit.a"
  if strings -a "$WORK/$kind/libgodotstorekit.a" | grep -E "/Users/|$GODOT|$WORK" | sort -u | head; then
    echo "[!!] build paths leaked into $kind lib"; exit 1
  fi

  rm -rf "$OUT/godotstorekit.$kind.xcframework"
  xcodebuild -create-xcframework -library "$WORK/$kind/libgodotstorekit.a" \
    -output "$OUT/godotstorekit.$kind.xcframework" >/dev/null
done
echo "[OK] $OUT/godotstorekit.{debug,release}.xcframework"
