#!/bin/zsh
# Visual audit: every screen in day and night, at default size and the largest
# accessibility size, on iPhone SE (3rd gen) and iPhone 17 Pro Max.
# Usage: scripts/audit-capture.sh screenshots/audit/<date>
# Output: <screen>-<day|night>-<se|max>-<default|ax5>.png
set -uo pipefail
cd "$(dirname "$0")/.."
OUT=${1:?output folder}
mkdir -p "$OUT"
DD=$PWD/build/audit-dd
RAW=$(mktemp -d)

# Each entry runs on a clean app (seeds only apply once).
TESTS=(
  OnboardingCaptureTests/testOnboardingAndGuides
  OnboardingCaptureTests/testTodayUnrated
  TodayCaptureTests/testTodayPieces
  BottomBarCaptureTests/testBar
  TodoInfoCaptureTests/testMorning
  TodoInfoCaptureTests/testBedtime
  TodoInfoCaptureTests/testAllDone
  TodoInfoCaptureTests/testPlan
  ProgressCaptureTests/testWeekAndMonth
  PlanV4CaptureTests/testWithLength
  PlanV4CaptureTests/testNoPlan
  PlanV3CaptureTests/testActiveItem
  PlanReviewCaptureTests/testReview
  SettingsCaptureTests/testSettings
  CaregiverCaptureTests/testCaregiverCard
  AuditCaptureTests/testLogAndUndo
  AuditCaptureTests/testTodoAfternoon
  AuditCaptureTests/testSinceVisitAndPlanPages
  AuditCaptureTests/testProgressEmpty
  AuditCaptureTests/testPlanImportOffline
  AuditCaptureTests/testSettingsPieces
)

sim() { # name, device type
  local id=$(xcrun simctl list devices | grep "$1 (" | grep -oE '[0-9A-F-]{36}' | head -1)
  [[ -n $id ]] || id=$(xcrun simctl create "$1" "$2" com.apple.CoreSimulator.SimRuntime.iOS-27-0)
  echo $id
}

setup() {
  xcrun simctl shutdown $1 2>/dev/null; xcrun simctl erase $1; xcrun simctl boot $1
  xcrun simctl bootstatus $1 >/dev/null 2>&1
  xcrun simctl status_bar $1 override --time 9:41 --batteryState discharging --batteryLevel 100 --wifiBars 3 --cellularMode active --cellularBars 4
  xcrun simctl spawn $1 defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true
  xcrun simctl ui $1 appearance light
  sleep 3
}

# A clean app (seeds only apply to an empty store): removing the app also
# removes its App Group data, and is much faster than erasing the simulator.
fresh() {
  xcrun simctl terminate $1 com.cursorkittens.calicare 2>/dev/null
  xcrun simctl uninstall $1 com.cursorkittens.calicare 2>/dev/null
  xcrun simctl uninstall $1 com.cursorkittens.calicare.designreview.xctrunner 2>/dev/null
  sleep 1
}

device() { # udid, short name
  local udid=$1 dev=$2
  setup $udid
  for variant in day night xxxl night-xxxl; do
    local folder=$RAW/$dev-$variant
    for t in $TESTS; do
      fresh $udid
      env TEST_RUNNER_DESIGN_OUT=$folder TEST_RUNNER_DESIGN_VARIANT=$variant xcodebuild -scheme DesignReview \
        -destination "platform=iOS Simulator,id=$udid" -derivedDataPath $DD -collect-test-diagnostics never \
        -only-testing:DesignReviewUITests/$t test-without-building > $RAW/$dev-$variant-${t//\//-}.log 2>&1
      grep -q "TEST SUCCEEDED" $RAW/$dev-$variant-${t//\//-}.log || echo "  ! $dev $variant $t failed (see $RAW)"
    done
    local mode=day size=default
    [[ $variant == night* ]] && mode=night
    [[ $variant == *xxxl ]] && size=ax5
    for f in $folder/*.png(N); do
      local name=$(basename ${f%.png})
      name=${name%-$variant}; name=${name%-day}; name=${name%-night}; name=${name%-xxxl}
      cp $f "$OUT/$name-$mode-$dev-$size.png"
    done
    echo "$dev $variant: $(ls $folder 2>/dev/null | grep -c png) shots"
  done
}

xcodebuild -scheme DesignReview -destination 'generic/platform=iOS Simulator' -derivedDataPath $DD build-for-testing 2>&1 | grep -E "error:|BUILD" | tail -1
PREFIX=${SIM_PREFIX:-Audit}
SE=$(sim "$PREFIX SE" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation)
MAX=$(sim "$PREFIX Max" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max)
device $SE se &
device $MAX max &
wait
echo "Logs: $RAW"
ls "$OUT" | wc -l
