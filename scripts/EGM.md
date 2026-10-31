# scripts

Source: `scripts/`

## Overview

Three standalone scripts and the unittest of one of them, with no package manifest. `ci.sh` (bash) is the one entry point for local runs and GitHub
Actions: lint, build, unit, UI and iPad UI stages over the `lily` scheme, with the UI test classes split into four
shards that CI runs from archived build-for-testing products. Every xcodebuild run logs under `build/results/`, and a
test stage fails unless the log proves a test ran. `l10n-check.py` (Python, read-only) validates the two string
catalogs against every `localized("...")` call site under `lily/` and the project's usage-description settings.
`make-app-icon.swift` renders the 1024 px app icon in three appearances plus Icon Composer layers and a preview strip;
`ci.sh` does not invoke it. `test_l10n_check.py` is the unittest for `l10n-check.py` and runs inside `lint`.

## Interface

### `ci.sh`

- Usage `./scripts/ci.sh [STAGE] [SHARD]`: `STAGE="${1:-all}"`, `SHARD="${2:-}"` (`scripts/ci.sh:STAGE`). Stages
  (`scripts/ci.sh:case "$STAGE"`):

| Stage | Runs |
|---|---|
| `lint` | `run_lint` |
| `build` | `run_xcodebuild build build` |
| `unit` | `run_unit_tests test` |
| `ui` | `run_ui_tests test` |
| `ui-ipad` | `run_ipad_ui_tests test` |
| `build-and-unit` | `run_lint`, `run_xcodebuild build build-for-testing`, `run_unit_tests test-without-building` |
| `archive-products` | `tar -czf "$PRODUCTS_ARCHIVE"` of `$PRODUCTS_DIR/Debug-iphonesimulator` and `*.xctestrun` (`COPYFILE_DISABLE=1`) |
| `restore-products` | `mkdir -p "$PRODUCTS_DIR"`, `tar -xzf "$PRODUCTS_ARCHIVE" -C "$PRODUCTS_DIR"` |
| `ui-shard <1..4 or ipad>` | `use_software_keyboard`, then `run_prebuilt_tests` on the shard's classes, or on `LilyIPadTests` for `ipad` |
| `all` | `run_lint`, build-for-testing, then unit, ui and ui-ipad as `test-without-building` |
| other | usage line to stderr, `exit 2` |

- Environment variables (`scripts/ci.sh:RESULTS_DIR`): `RESULTS_DIR` (default `build/results`), `DERIVED_DATA`
  (`build/DerivedData`; `PRODUCTS_DIR="$DERIVED_DATA/Build/Products"`), `PRODUCTS_ARCHIVE` (`build/products.tgz`),
  `XCODEBUILD_DESTINATION` (replaces the resolved iPhone destination in `run_xcodebuild`), `DESTINATION` and
  `IPAD_DESTINATION` (a pre-resolved `platform=iOS Simulator,id=<udid>`), `SWIFTLINT_VERSION` (pin checked by
  `require_swiftlint`). No `TEST_RUNNER_*` variable is read.
- Constants: `SCHEME="lily"`, `UNIT_TARGET="lilyTests"`, `UI_TARGET="lilyUITests"`, `IPAD_UI_TEST_CLASS="LilyIPadTests"`,
  `UI_BASE_CLASS="LilyUITestCase"`, `APP_BUNDLE_ID="iris.lily"`, `WARM_UP_SECONDS=8`, `CI_TEST_ITERATIONS=2`,
  `WARM_UP_TEST_IPHONE="lilyUITests/LilySmokeTests/testPrimaryActionReachesExploreFeed"`,
  `WARM_UP_TEST_IPAD="lilyUITests/LilyIPadTests/testLandingPlacesTheMiniatureBesideTheCopyOnIPad"`,
  `WARM_UP_TEST_SECONDS=300`, `CONSOLE_FILTER` (the `grep -E` shown on the console:
  `error:|/lily/.*: warning:|Test Suite .* (passed|failed)|Test Case .* (passed|failed)|Executed|Test case .* (passed|failed)|\*\* .* (SUCCEEDED|FAILED) \*\*`).
- `UI_SHARDS` (`scripts/ci.sh:UI_SHARDS`), four entries: 1 `LilyChatTests LilyProfileTests LilyDiscoverTests`;
  2 `LilyTournamentTests LilySignInTests LilyStateTests`; 3 `LilyEventEditTests LilyRosterTests LilyLanguageTests`;
  4 `LilySmokeTests LilyGroupsTests LilyPeopleTests`.
- Functions: `pick_device <family> <preferred>` (last available device matching `preferred`, else the family's last),
  `device_name <udid>`, `destination_udid <destination>`, `show_xcode_version`, `resolve_iphone_destination`
  (prefers `iPhone 17 Pro (`), `resolve_ipad_destination` (prefers `iPad Pro 13-inch`), `warm_up_simulator <udid>`,
  `run_logged <label> <action> [args]`, `report_retried_tests <label> <log>`, `run_xcodebuild <label> <action> [args]`,
  `require_executed_tests <label> <log>`, `check_executed_tests_gate`,
  `run_prebuilt_tests <label> <destination> <warm_up_test> [args]`, `warm_up_test_session`, `check_warm_up_tests`,
  `ui_test_classes [dir]`, `check_ui_test_classes_grep`, `check_ui_shards`, `ui_shard_only_testing <index>`,
  `require_swiftlint`, `run_lint`, `use_software_keyboard`, `run_unit_tests <action>`, `run_ui_tests <action>`,
  `run_ipad_ui_tests <action>`.
- `run_lint` (`scripts/ci.sh:run_lint`), in order: `require_swiftlint`; `swiftlint --strict --quiet --reporter emoji`;
  `python3 -I scripts/test_l10n_check.py`; `python3 -I scripts/l10n-check.py`; `check_ui_test_classes_grep`;
  `check_ui_shards`; `check_warm_up_tests`; `check_executed_tests_gate`.
- xcodebuild flags (`scripts/ci.sh:run_logged`): every run passes `-skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO`;
  test actions add `-parallel-testing-enabled NO -resultBundlePath "$RESULTS_DIR/<label>.xcresult"`; `run_xcodebuild`
  adds `-scheme lily -destination <...> -derivedDataPath "$DERIVED_DATA"`; `run_prebuilt_tests` adds
  `-xctestrun <file> -retry-tests-on-failure -test-iterations 2`; `run_unit_tests` passes `-only-testing:lilyTests`,
  `run_ui_tests` `-only-testing:lilyUITests`, `run_ipad_ui_tests` `-only-testing:lilyUITests/LilyIPadTests`.

### `l10n-check.py`

- Invocation `python3 -I scripts/l10n-check.py`, no arguments; `main()` prints one line per problem and returns 1 if
  any, else 0 (`scripts/l10n-check.py:main`). Inputs: `lily/Localizable.xcstrings`, `lily/InfoPlist.xcstrings`,
  `lily.xcodeproj/project.pbxproj`, every `lily/**/*.swift` except `Localized.swift`.
- `LANGUAGES = ["ru", "es", "fr", "uk", "pl", "pt"]`; `BRAND_KEYS = {"CFBundleDisplayName", "CFBundleName"}`
  (`scripts/l10n-check.py:LANGUAGES`).
- Functions: `literals()` (literal to the set of files using it), `joined(block)` (a multi-line literal as Swift
  reads it), `pattern(literal)` (an anchored regex over keys where each `\(...)` stands for one placeholder),
  `placeholders(text)`, `values(localization)` (the value and its plural variants), `literal_problems(strings, literals)`,
  `translation_problems(strings, languages, source_only, catalog)`, `usage_keys(pbxproj_text)` (Release and
  Debug-only `NS...UsageDescription` names), `infoplist_problems(strings, release_keys, debug_only_keys)`.
- Regexes: `LITERAL`, `MULTILINE`, `INTERPOLATION`, `PLACEHOLDER = %(?:\d+\$)?(?:lld|ld|d|@|lf|f|s)`,
  `USAGE_KEY = INFOPLIST_KEY_(NS\w+UsageDescription)`, `BUILD_CONFIGURATION` (`scripts/l10n-check.py:LITERAL`).

### `make-app-icon.swift`

- `swift scripts/make-app-icon.swift [output directory]`; `outDir` defaults to `/tmp/icon/out`
  (`scripts/make-app-icon.swift:outDir`); `size = 1024`; `enum Appearance: String { any, dark, tinted }`; `enum Letter`
  and `enum Glow` hold the geometry; functions `rgb`, `makeContext`, `write`, `gradient`, `roundedSystemFont`,
  `glyphPath`, `blurred`, `drawBackground`, `drawSeams`, `drawLetter`, `drawIcon`. Outputs: `final-any.png`,
  `final-dark.png`, `final-tinted.png`, `final-layer-background.png`, `final-layer-letter.png`, `preview-strip.png`
  (780 x 420).

## Invariants

- Every UI test class found by `ui_test_classes` except `LilyIPadTests` must be in exactly one `UI_SHARDS` entry
  (`lilyUITests/<class> is in <n> UI shards; it must be in exactly one UI_SHARDS entry of scripts/ci.sh`); every name
  in `UI_SHARDS` must be declared under `lilyUITests/`; `LilyIPadTests` must be declared and in no shard;
  `.github/workflows/ci.yml` must contain `shard: [1, 2, 3, 4, ipad]` (`scripts/ci.sh:check_ui_shards`).
- A test action passes only if its log matches `Test [Cc]ase '.*' passed|Test run with [1-9][0-9]* tests? in .* passed`;
  otherwise `exit 1` with `every test was skipped` or `no tests were executed` (`scripts/ci.sh:require_executed_tests`).
  `check_executed_tests_gate` self-tests the gate and `report_retried_tests` on six fixture logs, and
  `check_ui_test_classes_grep` self-tests `ui_test_classes` on five fixture files; lint fails on any mismatch.
- Both warm-up test methods must exist (`grep -q "func <name>()" lilyUITests/*.swift`); the warm-up run's own verdict
  is ignored (`scripts/ci.sh:check_warm_up_tests`, `scripts/ci.sh:warm_up_test_session`).
- `swiftlint` must be installed and, when `SWIFTLINT_VERSION` is set, `swiftlint version` must equal it; the script
  runs under `set -euo pipefail`, so one violation of `swiftlint --strict` fails `lint` (`scripts/ci.sh:require_swiftlint`).
- A `ui-shard` run needs a `*.xctestrun` directly under `$PRODUCTS_DIR` (`scripts/ci.sh:run_prebuilt_tests`); `SHARD`
  must be `ipad` or an integer in `1..4`, else `exit 2` (`scripts/ci.sh:ui_shard_only_testing`). A non-zero xcodebuild
  exit aborts the script with that code after printing the log's last 40 lines (`scripts/ci.sh:run_logged`).
- `l10n-check.py`: every `localized("...")` literal must match exactly one catalog key, and every key must be matched
  unless its `extractionState` is `manual` (`scripts/l10n-check.py:literal_problems`); every `Localizable.xcstrings`
  key, and every `InfoPlist.xcstrings` key outside `BRAND_KEYS`, must have all six languages, and each value's
  placeholders (plural variants included, positional prefixes ignored) must equal the key's
  (`scripts/l10n-check.py:translation_problems`); every `INFOPLIST_KEY_NS...UsageDescription` set in a Release
  configuration must be an `InfoPlist.xcstrings` key, and one set only in Debug must not be
  (`scripts/l10n-check.py:infoplist_problems`). The script only `json.loads` the catalogs; it has no round-trip or
  formatting check.
- `make-app-icon.swift` enforces nothing beyond `try!` and force unwraps: PNG encoding, the font glyph lookup and the
  CoreImage output must succeed or the script traps (`scripts/make-app-icon.swift:write`).

## Side Effects

- `cd "$(dirname "$0")/.."` then `mkdir -p "$RESULTS_DIR"` for every stage, `lint` included (`scripts/ci.sh:cd`).
- Writes `$RESULTS_DIR/<label>.log` for labels `build`, `unit-tests`, `ui-tests`, `ui-ipad-tests`, `ui-shard-<N>`;
  for test actions `rm -rf` then writes `$RESULTS_DIR/<label>.xcresult`; `warm_up_test_session` writes
  `$RESULTS_DIR/<label>-warm-up.log`; derived data goes under `$DERIVED_DATA`; `archive-products` writes
  `$PRODUCTS_ARCHIVE` (`scripts/ci.sh:run_logged`, `scripts/ci.sh:archive-products`).
- Simulator (`scripts/ci.sh:warm_up_simulator`, all `|| true`): `xcrun simctl bootstatus "$udid" -b`,
  `xcrun simctl install` of `lily.app`,
  `xcrun simctl launch "$udid" iris.lily -reset-session -mock-location -mock-auth -mock-events -freeze-aurora -app-language en`,
  `sleep 8`, `xcrun simctl terminate`;
  `warm_up_test_session` also terminates `iris.lily`. `xcrun simctl list devices available` is read-only. The script
  never calls `simctl boot`, `simctl shutdown`, `open -a Simulator` or `killall`.
- `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false` changes the host's Simulator.app
  preference in `run_ui_tests`, `run_ipad_ui_tests` and `ui-shard` (`scripts/ci.sh:use_software_keyboard`).
- Lint spawns `swiftlint` twice (`version`, then `--strict --quiet --reporter emoji`) and `python3 -I` twice, never
  `xcodebuild`; `check_ui_shards` reads
  `.github/workflows/ci.yml`; the two self-checks write fixtures into `mktemp -d` directories and remove them
  (`scripts/ci.sh:check_executed_tests_gate`, `scripts/ci.sh:check_ui_test_classes_grep`). No network access.
- `l10n-check.py` reads the catalogs, the pbxproj and the Swift sources, prints to stdout and writes nothing
  (`scripts/l10n-check.py:main`).
- `make-app-icon.swift` creates `outDir` (`FileManager.default.createDirectory`), writes the six PNGs and prints
  `wrote <name>.png` for each; it reads SF Pro Rounded through `NSFont.systemFont(ofSize:weight:)`
  (`scripts/make-app-icon.swift:outDir`, `scripts/make-app-icon.swift:write`).

## Verification

- Run: `./scripts/ci.sh lint` (SwiftLint, then `python3 -I scripts/test_l10n_check.py`, `python3 -I scripts/l10n-check.py`
  and the four `ci.sh` self-checks).
- Run: `python3 -I scripts/test_l10n_check.py` (the unittest for `l10n-check.py` on its own).
