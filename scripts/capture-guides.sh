#!/bin/zsh
# Captures real iOS screenshots for the setup guides and widget looks on a
# separate simulator ("CaliCare Captures"), so the everyday one isn't wiped.
# Output: design/screenshots/guide and design/screenshots/looks (JPG, 2x).
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="CaliCare Captures"
UDID=$(xcrun simctl list devices | grep "$SIM" | grep -oE '[0-9A-F-]{36}' | head -1)
RAW=$(mktemp -d)
DEST="platform=iOS Simulator,id=$UDID"

run() { # $1 test id, $2 output folder, extra env after
  local test=$1 out=$2; shift 2
  env TEST_RUNNER_DESIGN_OUT="$out" "$@" xcodebuild -scheme DesignReview -destination "$DEST" \
    -collect-test-diagnostics never -only-testing:"DesignReviewUITests/$test" test 2>&1 | grep -E "error:|TEST (SUCC|FAIL)" || true
}

xcrun simctl shutdown "$UDID" 2>/dev/null || true
xcrun simctl erase "$UDID"
xcrun simctl boot "$UDID"
xcrun simctl ui "$UDID" appearance light
sleep 5

run GuideCaptureTests/testSeed "$RAW/tour"
run GuideCaptureTests/testHomeGuide "$RAW/guide"
run GuideCaptureTests/testLockGuide "$RAW/guide"
run GuideCaptureTests/testControlGuide "$RAW/guide"

for variant in day night; do
  if [[ $variant == night ]]; then xcrun simctl ui "$UDID" appearance dark; looks=(default clear tinted)
  else xcrun simctl ui "$UDID" appearance light; looks=(default clear tinted); fi
  for look in $looks; do
    run GuideCaptureTests/testLook "$RAW/looks" TEST_RUNNER_DESIGN_VARIANT=$variant TEST_RUNNER_LOOK=$look
  done
done
xcrun simctl ui "$UDID" appearance light

for kind in guide looks; do
  mkdir -p design/screenshots/$kind
  for f in "$RAW"/$kind/*.png(N); do
    sips -Z 1748 -s format jpeg "$f" --out "design/screenshots/$kind/$(basename "${f%.png}").jpg" >/dev/null
  done
  [[ -f "$RAW/$kind/tap-spots.txt" ]] && cp "$RAW/$kind/tap-spots.txt" design/screenshots/$kind/
done
echo "Saved to design/screenshots/"
