#!/usr/bin/env bash
# Builds Lily and runs unit + UI tests on an iPhone simulator, and the iPad UI tests on an iPad simulator.
# Locally: ./scripts/ci.sh [lint|build|unit|ui|ui-ipad|all]
# GitHub Actions: ./scripts/ci.sh build-and-unit on one runner, then ./scripts/ci.sh ui-shard <1..N|ipad> on one
# runner per shard, each from the build products the first one archived (see .github/workflows/ci.yml).
set -euo pipefail

SCHEME="lily"
UNIT_TARGET="lilyTests"
UI_TARGET="lilyUITests"
# The iPad layouts have a UI test class of their own, run on an iPad; the rest of the UI suite stays on the iPhone.
IPAD_UI_TEST_CLASS="LilyIPadTests"
IPAD_UI_TESTS="$UI_TARGET/$IPAD_UI_TEST_CLASS"
# The iPhone UI classes grouped into shards of roughly equal running time, so CI runs them side by side and no job
# nears its timeout as the suite grows. Lint checks that every class under lilyUITests/ is in exactly one shard.
UI_SHARDS=(
  "LilyTournamentTests LilyPeopleTests LilyLanguageTests"
  "LilyChatTests LilySmokeTests LilyDiscoverTests"
  "LilyGroupsTests LilyEventEditTests LilySignInTests LilyProfileTests"
)
RESULTS_DIR="${RESULTS_DIR:-build/results}"
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products"
# What the build job hands the UI shard jobs (the simulator products and the .xctestrun), relative to the repository root.
PRODUCTS_ARCHIVE="${PRODUCTS_ARCHIVE:-build/products.tgz}"
STAGE="${1:-all}"
SHARD="${2:-}"

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

# The UI tests of one shard, run from the products of an earlier build-for-testing through its .xctestrun (no scheme,
# no project, no package resolution), so a runner that only downloaded the products can run them.
run_prebuilt_tests() {
  local label="$1" destination="$2"; shift 2
  local xctestrun
  xctestrun=$(find "$PRODUCTS_DIR" -maxdepth 1 -name '*.xctestrun' 2>/dev/null | head -1 || true)
  if [[ -z "$xctestrun" ]]; then
    echo "No .xctestrun under $PRODUCTS_DIR; run './scripts/ci.sh build-and-unit' (or restore the build products) first" >&2
    exit 1
  fi
  local log="$RESULTS_DIR/${label}.log"
  rm -rf "$RESULTS_DIR/${label}.xcresult"
  echo "==> ${label}"
  set +e
  xcodebuild test-without-building -xctestrun "$xctestrun" -destination "$destination" "$@" \
    -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/${label}.xcresult" \
    -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$log" \
    | { grep -E "error:|Test Suite .* (passed|failed)|Test Case .* (passed|failed)|Executed|\*\* .* (SUCCEEDED|FAILED) \*\*" || true; }
  local status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]]; then
    echo "==> ${label} FAILED (exit ${status}); last lines:" >&2
    tail -n 40 "$log" >&2
    exit "$status"
  fi
  require_executed_tests "$label" "$log"
}

# The UI test classes declared under lilyUITests/ (every `class LilyXxxTests: LilyUITestCase`), one per line.
ui_test_classes() {
  grep -hoE 'class Lily[A-Za-z0-9]+Tests: LilyUITestCase' lilyUITests/*.swift | sed -E 's/^class ([A-Za-z0-9]+):.*/\1/' | sort
}

# Every UI class must be in exactly one shard (or be the iPad class), or a new class would silently never run on CI.
check_ui_shards() {
  echo "==> ui shards"
  local classes listed
  classes=$(ui_test_classes)
  listed=$(printf '%s\n' "${UI_SHARDS[@]}" | tr ' ' '\n' | sort)
  local ok=1
  for class in $classes; do
    [[ "$class" == "$IPAD_UI_TEST_CLASS" ]] && continue
    local count
    count=$(printf '%s\n' "$listed" | grep -cx "$class" || true)
    if [[ "$count" -ne 1 ]]; then
      echo "lilyUITests/$class is in $count UI shards; it must be in exactly one UI_SHARDS entry of scripts/ci.sh" >&2
      ok=0
    fi
  done
  for class in $listed; do
    if ! printf '%s\n' "$classes" | grep -qx "$class"; then
      echo "UI_SHARDS in scripts/ci.sh names $class, which lilyUITests/ does not declare" >&2
      ok=0
    fi
  done
  # The workflow's matrix must name every shard, or a new UI_SHARDS entry would never run on CI.
  local matrix="" i
  for ((i = 1; i <= ${#UI_SHARDS[@]}; i++)); do matrix+="$i, "; done
  matrix="shard: [${matrix}ipad]"
  if ! grep -qF "$matrix" .github/workflows/ci.yml; then
    echo ".github/workflows/ci.yml must list every UI shard as '$matrix' (UI_SHARDS has ${#UI_SHARDS[@]} entries)" >&2
    ok=0
  fi
  [[ $ok -eq 1 ]] || exit 1
}

# -only-testing flags for shard N (1-based) of UI_SHARDS.
ui_shard_only_testing() {
  local index="$1"
  if ! [[ "$index" =~ ^[0-9]+$ ]] || (( index < 1 || index > ${#UI_SHARDS[@]} )); then
    echo "Unknown UI shard '$index'; use 1..${#UI_SHARDS[@]} or ipad" >&2
    exit 2
  fi
  for class in ${UI_SHARDS[index - 1]}; do
    echo "-only-testing:$UI_TARGET/$class"
  done
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
  check_ui_shards
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
  # CI's first job: lint, one build for testing, the unit tests from it; the products are then archived for the UI shards.
  build-and-unit)
    run_lint
    run_xcodebuild build build-for-testing
    run_xcodebuild unit-tests test-without-building -only-testing:"$UNIT_TARGET" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/unit-tests.xcresult"
    ;;
  # The products the UI shards need, as one tar: upload-artifact stores every file as 644, which no app launches with,
  # while tar keeps the executable bits. COPYFILE_DISABLE keeps macOS from adding ._ metadata files.
  archive-products)
    echo "==> archive products -> $PRODUCTS_ARCHIVE"
    (cd "$PRODUCTS_DIR" && COPYFILE_DISABLE=1 tar -czf "$OLDPWD/$PRODUCTS_ARCHIVE" Debug-iphonesimulator ./*.xctestrun)
    ;;
  restore-products)
    echo "==> restore products <- $PRODUCTS_ARCHIVE"
    mkdir -p "$PRODUCTS_DIR"
    tar -xzf "$PRODUCTS_ARCHIVE" -C "$PRODUCTS_DIR"
    ;;
  # CI's parallel jobs: one shard of the iPhone UI classes, or the iPad class on an iPad, from the archived products.
  ui-shard)
    use_software_keyboard
    if [[ "$SHARD" == "ipad" ]]; then
      IPAD_DESTINATION=$(ipad_destination)
      run_prebuilt_tests ui-ipad-tests "$IPAD_DESTINATION" -only-testing:"$IPAD_UI_TESTS"
    else
      # Assigned first: a failed substitution inside an argument list would not stop the script, and the
      # test run without -only-testing flags would be the whole UI target.
      ONLY_TESTING=$(ui_shard_only_testing "$SHARD")
      run_prebuilt_tests "ui-shard-${SHARD}" "$DESTINATION" $ONLY_TESTING
    fi
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
    echo "Usage: $0 [lint|build|unit|ui|ui-ipad|all|build-and-unit|ui-shard <1..${#UI_SHARDS[@]}|ipad>]" >&2
    exit 2
    ;;
esac
echo "==> ${STAGE} OK"
