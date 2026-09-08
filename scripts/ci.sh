#!/usr/bin/env bash
# Builds Lily and runs unit + UI tests on an iOS simulator.
# Used by GitHub Actions and locally: ./scripts/ci.sh [lint|build|unit|ui|all]
set -euo pipefail

SCHEME="lily"
UNIT_TARGET="lilyTests"
UI_TARGET="lilyUITests"
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

DEVICE=$(pick_simulator)
DESTINATION="platform=iOS Simulator,name=${DEVICE}"
echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "Destination: ${DESTINATION}"
mkdir -p "$RESULTS_DIR"

run_xcodebuild() {
  local label="$1"; shift
  local log="$RESULTS_DIR/${label}.log"
  rm -rf "$RESULTS_DIR/${label}.xcresult"
  echo "==> ${label}"
  set +e
  xcodebuild "$@" -scheme "$SCHEME" -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$log" \
    | { grep -E "error:|/lily/.*: warning:|Test Suite .* (passed|failed)|Test Case .* (passed|failed)|Executed|Test case .* (passed|failed)|\*\* .* (SUCCEEDED|FAILED) \*\*" || true; }
  local status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]]; then
    echo "==> ${label} FAILED (exit ${status}); last lines:" >&2
    tail -n 40 "$log" >&2
    exit "$status"
  fi
}

run_lint() {
  echo "==> lint"
  if ! command -v swiftlint >/dev/null; then
    echo "swiftlint not installed (brew install swiftlint)" >&2
    exit 1
  fi
  swiftlint --strict --quiet --reporter emoji
}

case "$STAGE" in
  lint)
    run_lint
    ;;
  build)
    run_xcodebuild build build
    ;;
  unit)
    run_xcodebuild unit-tests test -only-testing:"$UNIT_TARGET" -resultBundlePath "$RESULTS_DIR/unit-tests.xcresult"
    ;;
  ui)
    run_xcodebuild ui-tests test -only-testing:"$UI_TARGET" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/ui-tests.xcresult"
    ;;
  all)
    run_lint
    run_xcodebuild build build-for-testing
    run_xcodebuild unit-tests test-without-building -only-testing:"$UNIT_TARGET" -resultBundlePath "$RESULTS_DIR/unit-tests.xcresult"
    run_xcodebuild ui-tests test-without-building -only-testing:"$UI_TARGET" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/ui-tests.xcresult"
    ;;
  *)
    echo "Usage: $0 [lint|build|unit|ui|all]" >&2
    exit 2
    ;;
esac
echo "==> ${STAGE} OK"
