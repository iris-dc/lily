#!/usr/bin/env bash
# Builds Lily and runs unit + UI tests on an iPhone simulator, and the iPad UI tests on an iPad simulator.
# Used by GitHub Actions and locally: ./scripts/ci.sh [lint|build|unit|ui|ui-ipad|all]
set -euo pipefail

SCHEME="lily"
UNIT_TARGET="lilyTests"
UI_TARGET="lilyUITests"
# The iPad layouts have a UI test class of their own, run on an iPad; the rest of the UI suite stays on the iPhone.
IPAD_UI_TESTS="lilyUITests/LilyIPadTests"
RESULTS_DIR="${RESULTS_DIR:-build/results}"
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"
STAGE="${1:-all}"

cd "$(dirname "$0")/.."

pick_simulator() {
  # First available, shutdown-or-booted iPhone. Prefer the Pro model if present.
  local list
  list=$(xcrun simctl list devices available | grep -E "^[[:space:]]+iPhone" || true)
  local name
  name=$(echo "$list" | grep -m1 "iPhone 17 Pro (" | sed -E 's/^[[:space:]]+(.*) \([0-9A-F-]+\).*/\1/' || true)
  if [[ -z "$name" ]]; then
    name=$(echo "$list" | head -1 | sed -E 's/^[[:space:]]+(.*) \([0-9A-F-]+\).*/\1/')
  fi
  if [[ -z "$name" ]]; then
    echo "No iPhone simulator available" >&2
    xcrun simctl list devices available >&2
    exit 1
  fi
  echo "$name"
}

pick_ipad() {
  # First available iPad. Prefer the 13-inch Pro, the widest layout, if present.
  local list
  list=$(xcrun simctl list devices available | grep -E "^[[:space:]]+iPad" || true)
  local name
  name=$(echo "$list" | grep -m1 "iPad Pro 13-inch" | sed -E 's/^[[:space:]]+(.*) \([0-9A-F-]+\).*/\1/' || true)
  if [[ -z "$name" ]]; then
    name=$(echo "$list" | head -1 | sed -E 's/^[[:space:]]+(.*) \([0-9A-F-]+\).*/\1/')
  fi
  if [[ -z "$name" ]]; then
    echo "No iPad simulator available" >&2
    xcrun simctl list devices available >&2
    exit 1
  fi
  echo "$name"
}

DEVICE=$(pick_simulator)
DESTINATION="platform=iOS Simulator,name=${DEVICE}"
echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "Destination: ${DESTINATION}"
mkdir -p "$RESULTS_DIR"

# Only the stages that run on an iPad need one, so lint, build and unit still run on a Mac without an iPad simulator.
ipad_destination() {
  local ipad
  ipad=$(pick_ipad)
  echo "iPad destination: platform=iOS Simulator,name=${ipad}" >&2
  echo "platform=iOS Simulator,name=${ipad}"
}

# The destination is the iPhone unless XCODEBUILD_DESTINATION says otherwise (the iPad stage sets it).
run_xcodebuild() {
  local label="$1"; shift
  local action="$1"
  local log="$RESULTS_DIR/${label}.log"
  local destination="${XCODEBUILD_DESTINATION:-$DESTINATION}"
  rm -rf "$RESULTS_DIR/${label}.xcresult"
  echo "==> ${label}"
  set +e
  # Amplify pulls in smithy-swift, whose build plug-in xcodebuild refuses to validate without an interactive approval.
  xcodebuild "$@" -scheme "$SCHEME" -destination "$destination" -derivedDataPath "$DERIVED_DATA" \
    -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$log" \
    | { grep -E "error:|/lily/.*: warning:|Test Suite .* (passed|failed)|Test Case .* (passed|failed)|Executed|Test case .* (passed|failed)|\*\* .* (SUCCEEDED|FAILED) \*\*" || true; }
  local status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]]; then
    echo "==> ${label} FAILED (exit ${status}); last lines:" >&2
    tail -n 40 "$log" >&2
    exit "$status"
  fi
  case "$action" in
    test|test-without-building) require_executed_tests "$label" "$log" ;;
  esac
}

# xcodebuild exits 0 and prints a passing suite when -only-testing matches nothing (a renamed target or test bundle),
# so a green test stage must also show a test that ran: XCTest prints "Test Case '...' passed" and "Executed N tests";
# Swift Testing prints "Test case '...' passed" per clone when parallel testing is on and, without clones,
# "Test run with N tests in M suites passed" at the end.
require_executed_tests() {
  local label="$1" log="$2"
  if ! grep -qE "Test [Cc]ase '.*' passed|Executed [1-9][0-9]* tests?|Test run with [1-9][0-9]* tests? in .* passed" "$log"; then
    echo "==> ${label}: no tests were executed" >&2
    exit 1
  fi
}

run_lint() {
  echo "==> lint"
  if ! command -v swiftlint >/dev/null; then
    echo "swiftlint not installed (brew install swiftlint)" >&2
    exit 1
  fi
  swiftlint --strict --quiet --reporter emoji
  # Every localized("...") in the code must be a catalog key translated into every language the app ships.
  echo "==> l10n"
  python3 scripts/l10n-check.py
}

# The UI tests type into text fields, which needs the simulator's software keyboard; with "Connect Hardware Keyboard"
# on (Xcode's default on a developer Mac) typeText finds no keyboard and the create-flow test fails. This is a
# preference of Simulator.app on the host, idempotent, and never touches CoreSimulatorService.
use_software_keyboard() {
  defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
}

case "$STAGE" in
  lint)
    run_lint
    ;;
  build)
    run_xcodebuild build build
    ;;
  unit)
    run_xcodebuild unit-tests test -only-testing:"$UNIT_TARGET" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/unit-tests.xcresult"
    ;;
  ui)
    use_software_keyboard
    run_xcodebuild ui-tests test -only-testing:"$UI_TARGET" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/ui-tests.xcresult"
    ;;
  ui-ipad)
    IPAD_DESTINATION=$(ipad_destination)
    use_software_keyboard
    XCODEBUILD_DESTINATION="$IPAD_DESTINATION" run_xcodebuild ui-ipad-tests test -only-testing:"$IPAD_UI_TESTS" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/ui-ipad-tests.xcresult"
    ;;
  all)
    run_lint
    run_xcodebuild build build-for-testing
    run_xcodebuild unit-tests test-without-building -only-testing:"$UNIT_TARGET" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/unit-tests.xcresult"
    use_software_keyboard
    run_xcodebuild ui-tests test-without-building -only-testing:"$UI_TARGET" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/ui-tests.xcresult"
    # The iPhone build's simulator products are arm64 like the iPad's, so the iPad stage runs them without a rebuild.
    IPAD_DESTINATION=$(ipad_destination)
    XCODEBUILD_DESTINATION="$IPAD_DESTINATION" run_xcodebuild ui-ipad-tests test-without-building -only-testing:"$IPAD_UI_TESTS" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/ui-ipad-tests.xcresult"
    ;;
  *)
    echo "Usage: $0 [lint|build|unit|ui|ui-ipad|all]" >&2
    exit 2
    ;;
esac
echo "==> ${STAGE} OK"
