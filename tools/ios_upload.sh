#!/bin/sh
# Builds the iPhone app, signs it for the App Store with team ZK8UX8XUW9, and uploads it to App Store
# Connect (it then appears in TestFlight). Needs: Xcode signed in with the Apple ID that owns that team,
# and the app record for com.toyplanesim.game created in App Store Connect.
#   ./tools/ios_upload.sh            build + upload
#   ./tools/ios_upload.sh --no-upload  build and sign only (writes the .ipa)
set -e
cd "$(dirname "$0")/.."
TEAM=ZK8UX8XUW9
OUT=/tmp/out/ios_release
rm -rf $OUT && mkdir -p $OUT
godot --headless --export-release "iOS" $OUT/ToyPlaneArcade.ipa > $OUT/export.log 2>&1 || true
ARCHIVE=$(ls -d $OUT/*.xcarchive 2>/dev/null | head -1)
if [ -z "$ARCHIVE" ]; then
	grep -E " error:" $OUT/export.log | head -5
	echo "Archive failed (log: $OUT/export.log). Is Xcode signed in with team $TEAM?"
	exit 1
fi
DEST=upload
[ "$1" = "--no-upload" ] && DEST=export
cat > $OUT/options.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>method</key><string>app-store-connect</string>
	<key>teamID</key><string>$TEAM</string>
	<key>destination</key><string>$DEST</string>
	<key>signingStyle</key><string>automatic</string>
	<key>uploadSymbols</key><true/>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist $OUT/options.plist -exportPath $OUT/export -allowProvisioningUpdates
echo "Done ($DEST). It shows up in App Store Connect > TestFlight after Apple processes it (5-30 min)."
