#!/bin/zsh
# App Store screenshots, 6.9" (iPhone 17 Pro Max, 1320 × 2868), from the
# current app with the realistic demo plan. Output: screenshots/appstore/.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT=screenshots/appstore
DD=$PWD/build/store-dd
RAW=$(mktemp -d)
UDID=$(xcrun simctl list devices | grep "Store Max (" | grep -oE '[0-9A-F-]{36}' | head -1)
[[ -n $UDID ]] || UDID=$(xcrun simctl create "Store Max" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-0)
xcrun simctl boot $UDID 2>/dev/null; xcrun simctl bootstatus $UDID >/dev/null 2>&1
xcrun simctl status_bar $UDID override --time 9:41 --batteryState discharging --batteryLevel 100 --wifiBars 3 --cellularMode active --cellularBars 4
xcodebuild -scheme DesignReview -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath $DD build-for-testing 2>&1 | grep -E "error:|BUILD" | tail -1
mkdir -p $OUT
n=1
for shot in plan:day todo:day today:day progress:day todo:night; do
  kind=${shot%%:*} variant=${shot##*:}
  xcrun simctl uninstall $UDID com.cursorkittens.calicare 2>/dev/null
  env TEST_RUNNER_DESIGN_OUT=$RAW TEST_RUNNER_DESIGN_VARIANT=$variant TEST_RUNNER_SITE_SHOT=$kind xcodebuild -scheme DesignReview \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath $DD -collect-test-diagnostics never \
    -only-testing:DesignReviewUITests/SiteShotsTests/testShot test-without-building 2>&1 | grep -E "error:|TEST (SUCC|FAIL)" | tail -1
  cp $RAW/site-$kind-$variant.png "$OUT/$n-$kind-$variant.png" && n=$((n + 1))
done
sips -g pixelWidth -g pixelHeight $OUT/*.png | grep pixel | sort | uniq -c
