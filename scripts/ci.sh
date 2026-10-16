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
# What every UI test class derives from (the base itself derives from XCTestCase); lint lists the classes by it.
UI_BASE_CLASS="LilyUITestCase"
# The iPhone UI classes grouped into shards of roughly equal running time on the GitHub runner (about 18 minutes of
# tests each, measured there: Chat 751 s, Tournament 732, EventEdit 718, Smoke 409, Groups 409, Roster 289, SignIn 200,
# Profile 182, People 156, Discover 150, State 143, Language 73), so no job nears its timeout as the suite grows; three
# shards had put 34 minutes of tests in one job, which a slow runner took past the limit. Lint checks that every test
# class under lilyUITests/ (whatever its name, see ui_test_classes) is in exactly one shard, that the iPad class is in
# none, and that the workflow's matrix lists every shard.
UI_SHARDS=(
  "LilyChatTests LilyProfileTests LilyDiscoverTests"
  "LilyTournamentTests LilySignInTests LilyStateTests"
  "LilyEventEditTests LilyRosterTests LilyLanguageTests"
  "LilySmokeTests LilyGroupsTests LilyPeopleTests"
)
RESULTS_DIR="${RESULTS_DIR:-build/results}"
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products"
# What the build job hands the UI shard jobs (the simulator products and the .xctestrun), relative to the repository root.
PRODUCTS_ARCHIVE="${PRODUCTS_ARCHIVE:-build/products.tgz}"
# The app the UI stages warm the simulator up with, and how long its one launch is given before it is terminated.
APP_BUNDLE_ID="iris.lily"
WARM_UP_SECONDS=8
# How often a failing test of a CI shard is run before the shard fails (xcodebuild -retry-tests-on-failure): a second
# attempt for the launch and query timeouts a cold GitHub runner produces, which no test can guard against. Every test
# that passed only on a retry is named in the log, so a flake never passes unseen.
CI_TEST_ITERATIONS=2
# What of xcodebuild's output reaches the console (errors, the app's warnings, test and build verdicts); the whole of it goes to the log.
CONSOLE_FILTER="error:|/lily/.*: warning:|Test Suite .* (passed|failed)|Test Case .* (passed|failed)|Executed|Test case .* (passed|failed)|\*\* .* (SUCCEEDED|FAILED) \*\*"
XCODE_VERSION_SHOWN=0
STAGE="${1:-all}"
SHARD="${2:-}"

cd "$(dirname "$0")/.."

# The simulator of a family to run on, as its UDID: the preferred model when present (the Pro iPhone; the 13-inch iPad
# Pro as the widest layout), else the family's last listed device; of two runtimes carrying the same device name the
# newest, which simctl lists last and which xcodebuild would also pick by name. The warm-up and xcodebuild are both
# given this one UDID: resolved twice by name, they once booted two iPads of the same name on a runner with two
# runtimes, and the shard ran at a third of its speed.
pick_device() {
  local family="$1" preferred="$2"
  local list
  list=$(xcrun simctl list devices available | grep -E "^[[:space:]]+${family}" || true)
  local line
  line=$(echo "$list" | grep -F "$preferred" | tail -1 || true)
  if [[ -z "$line" ]]; then
    line=$(echo "$list" | tail -1)
  fi
  if [[ -z "$line" ]]; then
    echo "No ${family} simulator available" >&2
    xcrun simctl list devices available >&2
    exit 1
  fi
  echo "$line" | sed -E 's/^.*\(([0-9A-F-]+)\) \([A-Za-z]+\).*$/\1/'
}

# The name of the simulator with the given UDID, for the log.
device_name() {
  xcrun simctl list devices available | grep -F "($1)" | head -1 | sed -E 's/^[[:space:]]+(.*) \([0-9A-F-]+\).*/\1/'
}

# The UDID behind a destination string: its id, or the newest device of its name (XCODEBUILD_DESTINATION may name one).
destination_udid() {
  local destination="$1"
  case "$destination" in
    *id=*) echo "${destination#*id=}" | cut -d, -f1 ;;
    *name=*) xcrun simctl list devices available | grep -F "${destination#*name=} (" | tail -1 \
      | sed -E 's/^.*\(([0-9A-F-]+)\) \([A-Za-z]+\).*$/\1/' ;;
  esac
}

mkdir -p "$RESULTS_DIR"

# Printed once per run, by the first stage that runs xcodebuild.
show_xcode_version() {
  if [[ "$XCODE_VERSION_SHOWN" -eq 0 ]]; then
    echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
    XCODE_VERSION_SHOWN=1
  fi
}

# Picked once by the first stage that runs xcodebuild on an iPhone; lint, archive-products and restore-products never
# do, so they run on a Mac whose simulator runtimes are unavailable. Sets the global DESTINATION: call it as a plain
# statement, never inside $(...).
resolve_iphone_destination() {
  if [[ -z "${DESTINATION:-}" ]]; then
    local udid
    udid=$(pick_device iPhone "iPhone 17 Pro (")
    DESTINATION="platform=iOS Simulator,id=${udid}"
    echo "Destination: ${DESTINATION} ($(device_name "$udid"))"
  fi
}

# Only the stages that run on an iPad need one, so lint, build and unit still run on a Mac without an iPad simulator.
# Sets the global IPAD_DESTINATION: call it as a plain statement, never inside $(...).
resolve_ipad_destination() {
  if [[ -z "${IPAD_DESTINATION:-}" ]]; then
    local udid
    udid=$(pick_device iPad "iPad Pro 13-inch")
    IPAD_DESTINATION="platform=iOS Simulator,id=${udid}"
    echo "iPad destination: ${IPAD_DESTINATION} ($(device_name "$udid"))"
  fi
}

# Boots the simulator and runs the built app once before a UI stage. On a cold GitHub runner the first XCTest launch of
# a shard timed out at 60 s before any assertion (the language test) and the iPad's first accessibility queries timed
# out the same way; one warm launch, with the mock arguments so it reaches no network, takes that cost off the first
# test. Best effort: every step is allowed to fail, and the app is only launched when the products are there.
warm_up_simulator() {
  local udid="$1"
  if [[ -z "$udid" ]]; then
    echo "warm-up: no simulator to warm up" >&2
    return 0
  fi
  echo "==> warm-up ($(device_name "$udid"))"
  # bootstatus -b boots the device when it is not booted and waits until it is.
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  local app="$PRODUCTS_DIR/Debug-iphonesimulator/${SCHEME}.app"
  if [[ -d "$app" ]]; then
    xcrun simctl install "$udid" "$app" >/dev/null 2>&1 || true
    xcrun simctl launch "$udid" "$APP_BUNDLE_ID" -reset-session -mock-location -mock-auth -mock-events -freeze-aurora \
      -app-language en >/dev/null 2>&1 || true
    sleep "$WARM_UP_SECONDS"
    xcrun simctl terminate "$udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  fi
}

# One xcodebuild run: the log and the result bundle land under RESULTS_DIR/<label>.*, tests run without simulator clones
# (clones make the unit suite take minutes on a loaded runner and a timing-based test flaky), a failure is shown with
# the log's tail, and a test action must prove that it ran a test.
run_logged() {
  local label="$1" action="$2"; shift 2
  local log="$RESULTS_DIR/${label}.log" is_test=0
  case "$action" in
    test|test-without-building)
      is_test=1
      set -- "$@" -parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/${label}.xcresult"
      ;;
  esac
  show_xcode_version
  rm -rf "$RESULTS_DIR/${label}.xcresult"
  echo "==> ${label}"
  set +e
  # Amplify pulls in smithy-swift, whose build plug-in xcodebuild refuses to validate without an interactive approval.
  xcodebuild "$action" "$@" -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$log" \
    | { grep -E "$CONSOLE_FILTER" || true; }
  local status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]]; then
    echo "==> ${label} FAILED (exit ${status}); last lines:" >&2
    tail -n 40 "$log" >&2
    exit "$status"
  fi
  [[ $is_test -eq 0 ]] || { require_executed_tests "$label" "$log"; report_retried_tests "$label" "$log"; }
}

# Names every test that failed and then passed within one run (a CI retry), so the log shows the flake.
report_retried_tests() {
  local label="$1" log="$2" retried
  retried=$(grep -oE "Test Case '[^']+' failed" "$log" | sed -E "s/Test Case '([^']+)' failed/\1/" | sort -u \
    | while IFS= read -r name; do grep -qF "Test Case '${name}' passed" "$log" && echo "$name"; done || true)
  [[ -z "$retried" ]] || echo "==> ${label}: passed only on a retry: ${retried//$'\n'/, }"
}

# The destination is the iPhone unless XCODEBUILD_DESTINATION says otherwise (the iPad stage sets it).
run_xcodebuild() {
  local label="$1" action="$2"; shift 2
  local destination="${XCODEBUILD_DESTINATION:-}"
  if [[ -z "$destination" ]]; then
    resolve_iphone_destination
    destination="$DESTINATION"
  fi
  run_logged "$label" "$action" "$@" -scheme "$SCHEME" -destination "$destination" -derivedDataPath "$DERIVED_DATA"
}

# xcodebuild exits 0 and prints a passing suite when -only-testing matches nothing (a renamed target or test bundle),
# and a stage whose every test skipped itself (LilyIPadTests alone on an iPhone, a class-level XCTSkip) ends the same
# way with "Executed N tests, with N tests skipped", so a green test stage must show a test that passed: XCTest prints
# "Test Case '...' passed" per test, Swift Testing "Test case '...' passed" per clone with parallel testing on and,
# without clones, "Test run with N tests in M suites passed".
require_executed_tests() {
  local label="$1" log="$2"
  if grep -qE "Test [Cc]ase '.*' passed|Test run with [1-9][0-9]* tests? in .* passed" "$log"; then
    return
  fi
  local counts executed="" skipped=""
  counts=$(grep -oE "Executed [0-9]+ tests?, with [0-9]+ tests? skipped" "$log" | tail -1 \
    | grep -oE "[0-9]+" | tr '\n' ' ' || true)
  read -r executed skipped <<< "$counts"
  if [[ -n "$executed" && "$executed" -eq "$skipped" ]]; then
    echo "==> ${label}: every test was skipped" >&2
  else
    echo "==> ${label}: no tests were executed" >&2
  fi
  exit 1
}

# The gate's own test, run by lint, so a regression in the pattern cannot go unnoticed.
check_executed_tests_gate() {
  echo "==> test gate"
  local dir ok=1 name
  dir=$(mktemp -d)
  printf '%s\n' "Test Case '-[lilyUITests.LilySmokeTests testLanding]' passed (1.0 seconds)." > "$dir/xctest.log"
  printf '%s\n' "✔ Test run with 1638 tests in 237 suites passed after 36.263 seconds." > "$dir/swift-testing.log"
  printf '%s\n' "Test Case '-[lilyUITests.LilyIPadTests testSplit]' skipped (0.070 seconds)." \
    "Executed 7 tests, with 7 tests skipped and 0 failures (0 unexpected) in 0.375 (0.379) seconds" > "$dir/skipped.log"
  printf '%s\n' "Executed 5 tests, with 0 failures (0 unexpected) in 99.105 (99.107) seconds" "** TEST SUCCEEDED **" \
    > "$dir/summary-only.log"
  : > "$dir/empty.log"
  for name in xctest swift-testing; do
    (require_executed_tests "$name" "$dir/$name.log" 2>/dev/null) \
      || { echo "require_executed_tests rejected $name.log, which shows a passed test" >&2; ok=0; }
  done
  for name in skipped summary-only empty; do
    if (require_executed_tests "$name" "$dir/$name.log" 2>/dev/null); then
      echo "require_executed_tests accepted $name.log, which shows no passed test" >&2
      ok=0
    fi
  done
  local message
  message=$( (require_executed_tests skipped "$dir/skipped.log") 2>&1 || true)
  [[ "$message" == *"every test was skipped"* ]] \
    || { echo "require_executed_tests must say 'every test was skipped' for skipped.log" >&2; ok=0; }
  # A retried test (failed, then passed, in one log) is named; a log without one prints nothing.
  printf '%s\n' "Test Case '-[lilyUITests.LilyIPadTests testSplit]' failed (185.6 seconds)." \
    "Test Case '-[lilyUITests.LilyIPadTests testSplit]' passed (27.1 seconds)." \
    "Test Case '-[lilyUITests.LilyIPadTests testGrid]' passed (14.0 seconds)." > "$dir/retried.log"
  message=$(report_retried_tests retried "$dir/retried.log")
  [[ "$message" == *"passed only on a retry: -[lilyUITests.LilyIPadTests testSplit]" ]] \
    || { echo "report_retried_tests must name testSplit alone for retried.log; it printed: ${message}" >&2; ok=0; }
  message=$(report_retried_tests clean "$dir/xctest.log")
  [[ -z "$message" ]] || { echo "report_retried_tests must print nothing for xctest.log; it printed: ${message}" >&2; ok=0; }
  rm -rf "$dir"
  [[ $ok -eq 1 ]] || exit 1
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
  warm_up_simulator "$(destination_udid "$destination")"
  run_logged "$label" test-without-building "$@" -xctestrun "$xctestrun" -destination "$destination" \
    -retry-tests-on-failure -test-iterations "$CI_TEST_ITERATIONS"
}

# The UI test classes declared under the directory (lilyUITests/ by default), one per line: every class deriving from
# LilyUITestCase or XCTestCase directly, whatever its name, except the base class. -o lets the `final` and
# `@MainActor final` prefixes through; the trailing [[:space:],{] keeps a `LilyUITestCaseProtocol`-style name out
# (no \b: BSD grep).
ui_test_classes() {
  local dir="${1:-lilyUITests}"
  grep -hoE "class [A-Za-z0-9_]+: *(${UI_BASE_CLASS}|XCTestCase)[[:space:],{]" "$dir"/*.swift \
    | sed -E 's/^class ([A-Za-z0-9_]+):.*/\1/' | grep -vx "$UI_BASE_CLASS" | sort
}

# The grep's own test: a class named outside the LilyXxxTests scheme or deriving from XCTestCase directly must be
# listed too, or it could sit in no shard with lint green.
check_ui_test_classes_grep() {
  echo "==> ui test classes"
  local dir found
  dir=$(mktemp -d)
  printf '%s\n' 'final class ScratchTests: XCTestCase {' > "$dir/ScratchTests.swift"
  printf '%s\n' '@MainActor final class IPadLayoutTests: LilyUITestCase {' > "$dir/IPadLayoutTests.swift"
  printf '%s\n' 'class LilyUITestCase: XCTestCase {' > "$dir/LilyUITestCase.swift"
  printf '%s\n' 'extension LilyFooTests {' > "$dir/LilyFooTests+Helpers.swift"
  printf '%s\n' 'final class LilyUITestCaseSpy: LilyUITestCaseProtocol {' > "$dir/Spy.swift"
  found=$(ui_test_classes "$dir" || true)
  rm -rf "$dir"
  if [[ "$found" != $'IPadLayoutTests\nScratchTests' ]]; then
    echo "ui_test_classes must list exactly IPadLayoutTests and ScratchTests from the fixture files; it listed:" \
      "${found//$'\n'/ }" >&2
    exit 1
  fi
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
  # The iPad class runs on an iPad through 'ui-shard ipad' and skips itself on an iPhone, so it must be declared and
  # be in no iPhone shard.
  if printf '%s\n' "$listed" | grep -qx "$IPAD_UI_TEST_CLASS"; then
    echo "UI_SHARDS in scripts/ci.sh lists $IPAD_UI_TEST_CLASS, which runs on an iPad through 'ui-shard ipad'" \
      "and would only skip itself in an iPhone shard" >&2
    ok=0
  fi
  if ! printf '%s\n' "$classes" | grep -qx "$IPAD_UI_TEST_CLASS"; then
    echo "lilyUITests/ does not declare $IPAD_UI_TEST_CLASS, which scripts/ci.sh runs on an iPad" >&2
    ok=0
  fi
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

# CI exports the pin and installs that release; a run that lints with another copy on PATH would lint with a version
# nobody chose. A developer Mac sets no pin and lints with what brew installed.
require_swiftlint() {
  if ! command -v swiftlint >/dev/null; then
    echo "swiftlint not installed (brew install swiftlint)" >&2
    exit 1
  fi
  local version
  version=$(swiftlint version)
  echo "SwiftLint ${version}"
  if [[ -n "${SWIFTLINT_VERSION:-}" && "$version" != "$SWIFTLINT_VERSION" ]]; then
    echo "swiftlint is ${version}, CI pins ${SWIFTLINT_VERSION} (.github/workflows/ci.yml)" >&2
    exit 1
  fi
}

run_lint() {
  echo "==> lint"
  require_swiftlint
  swiftlint --strict --quiet --reporter emoji
  # Every localized("...") in the code must be a catalog key translated into every language the app ships, and the
  # usage descriptions a Release build sets must be in InfoPlist.xcstrings. The checker's own tests run first:
  # `placeholders` and `values` can regress with the real catalog still passing. Both import only the standard
  # library, so isolated mode costs nothing and keeps a planted module out.
  echo "==> l10n"
  python3 -I scripts/test_l10n_check.py
  python3 -I scripts/l10n-check.py
  check_ui_test_classes_grep
  check_ui_shards
  check_executed_tests_gate
}

# The UI tests type into text fields, which needs the simulator's software keyboard; with "Connect Hardware Keyboard"
# on (Xcode's default on a developer Mac) typeText finds no keyboard and the create-flow test fails. This is a
# preference of Simulator.app on the host, idempotent, and never touches CoreSimulatorService.
use_software_keyboard() {
  defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
}

# The test stages, each holding its flags once; the argument is the action, test or test-without-building.
run_unit_tests() {
  run_xcodebuild unit-tests "$1" -only-testing:"$UNIT_TARGET"
}

run_ui_tests() {
  use_software_keyboard
  resolve_iphone_destination
  warm_up_simulator "$(destination_udid "${XCODEBUILD_DESTINATION:-$DESTINATION}")"
  run_xcodebuild ui-tests "$1" -only-testing:"$UI_TARGET"
}

run_ipad_ui_tests() {
  use_software_keyboard
  resolve_ipad_destination
  warm_up_simulator "$(destination_udid "$IPAD_DESTINATION")"
  XCODEBUILD_DESTINATION="$IPAD_DESTINATION" run_xcodebuild ui-ipad-tests "$1" -only-testing:"$IPAD_UI_TESTS"
}

case "$STAGE" in
  lint)
    run_lint
    ;;
  build)
    run_xcodebuild build build
    ;;
  unit)
    run_unit_tests test
    ;;
  ui)
    run_ui_tests test
    ;;
  ui-ipad)
    run_ipad_ui_tests test
    ;;
  # CI's first job: lint, one build for testing, the unit tests from it; the products are then archived for the UI shards.
  build-and-unit)
    run_lint
    run_xcodebuild build build-for-testing
    run_unit_tests test-without-building
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
      resolve_ipad_destination
      run_prebuilt_tests ui-ipad-tests "$IPAD_DESTINATION" -only-testing:"$IPAD_UI_TESTS"
    else
      # Assigned first: a failed substitution inside an argument list would not stop the script, and the
      # test run without -only-testing flags would be the whole UI target.
      ONLY_TESTING=$(ui_shard_only_testing "$SHARD")
      resolve_iphone_destination
      run_prebuilt_tests "ui-shard-${SHARD}" "$DESTINATION" $ONLY_TESTING
    fi
    ;;
  all)
    run_lint
    run_xcodebuild build build-for-testing
    run_unit_tests test-without-building
    run_ui_tests test-without-building
    # The iPhone build's simulator products are arm64 like the iPad's, so the iPad stage runs them without a rebuild.
    run_ipad_ui_tests test-without-building
    ;;
  *)
    echo "Usage: $0 [lint|build|unit|ui|ui-ipad|all|build-and-unit|ui-shard <1..${#UI_SHARDS[@]}|ipad>]" >&2
    exit 2
    ;;
esac
echo "==> ${STAGE} OK"
