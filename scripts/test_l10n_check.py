#!/usr/bin/env python3
"""The checker's own tests over fixtures, run by ./scripts/ci.sh lint as `python3 -I scripts/test_l10n_check.py` before
the checker itself: `placeholders` and `values` can regress with the real catalog still passing, so every rule has a
fixture here. The checks are functions over data, and every fixture is a literal dict or string; nothing is read from
disk. The checker's file name has a hyphen and isolated mode adds no script directory to sys.path, so it is loaded
from its path rather than imported."""
import importlib.util
import sys
import unittest
from pathlib import Path

# Loading by path would compile the checker into scripts/__pycache__ whatever flags the caller passes.
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("l10n_check", Path(__file__).resolve().with_name("l10n-check.py"))
l10n_check = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(l10n_check)

SOURCE = Path("lily/Features/Scratch.swift")
ENGLISH_AND_RUSSIAN = {"Hello": {"localizations": {"en": {"stringUnit": {"value": "Hello"}},
                                                   "ru": {"stringUnit": {"value": "Привет"}}}}}


def string_unit(value):
    return {"stringUnit": {"value": value}}


def plural(**forms):
    return {"variations": {"plural": {form: string_unit(value) for form, value in forms.items()}}}


def configuration(name, **settings):
    """One XCBuildConfiguration's settings in the pbxproj's shape, followed by the configuration's name."""
    lines = "".join(f'\t\t\t\t{setting} = "{value}";\n' for setting, value in settings.items())
    return f"\t\t\tbuildSettings = {{\n{lines}\t\t\t}};\n\t\t\tname = {name};\n"


class PlaceholdersTests(unittest.TestCase):
    def test_positions_are_dropped_so_reordered_arguments_match(self):
        self.assertEqual(l10n_check.placeholders("%2$@ %1$lld"), ["%@", "%lld"])
        self.assertEqual(l10n_check.placeholders("%2$@ %1$lld"), l10n_check.placeholders("%lld %@"))

    def test_every_supported_type_is_kept(self):
        self.assertEqual(
            l10n_check.placeholders("%lld %ld %d %@ %lf %f %s"), ["%@", "%d", "%f", "%ld", "%lf", "%lld", "%s"]
        )

    def test_a_bare_percent_is_no_placeholder(self):
        self.assertEqual(l10n_check.placeholders("100% done"), [])

    def test_differing_placeholders_do_not_compare_equal(self):
        self.assertNotEqual(l10n_check.placeholders("%@"), l10n_check.placeholders("%lld"))


class ValuesTests(unittest.TestCase):
    def test_plural_variants_follow_the_string_unit(self):
        localization = {**string_unit("unit"), **plural(one="one", other="other")}
        self.assertEqual(list(l10n_check.values(localization)), ["unit", "one", "other"])

    def test_a_string_unit_alone_yields_itself(self):
        self.assertEqual(list(l10n_check.values(string_unit("unit"))), ["unit"])

    def test_plural_variants_alone_are_yielded(self):
        self.assertEqual(list(l10n_check.values(plural(one="one", other="other"))), ["one", "other"])


class PatternTests(unittest.TestCase):
    def test_an_interpolation_stands_for_one_placeholder_of_any_type(self):
        pattern = l10n_check.pattern("\\(n) spots left")
        self.assertIsNotNone(pattern.match("%lld spots left"))
        self.assertIsNotNone(pattern.match("%@ spots left"))
        self.assertIsNone(pattern.match("spots left"))
        self.assertIsNone(pattern.match("%lld %@ spots left"))

    def test_a_nested_call_inside_an_interpolation_is_one_placeholder(self):
        self.assertIsNotNone(l10n_check.pattern("\\(count.formatted(.number)) joined").match("%@ joined"))

    def test_an_escaped_quote_matches_the_keys_quote(self):
        self.assertIsNotNone(l10n_check.pattern('Say \\"hi\\"').match('Say "hi"'))

    def test_regex_characters_in_a_literal_are_literal(self):
        pattern = l10n_check.pattern("Today (12:00)")
        self.assertIsNotNone(pattern.match("Today (12:00)"))
        self.assertIsNone(pattern.match("Today 12:00"))


class JoinedTests(unittest.TestCase):
    def test_a_trailing_backslash_joins_lines(self):
        self.assertEqual(l10n_check.joined("    Join the game \\\n    tonight"), "Join the game tonight")

    def test_lines_without_a_backslash_keep_their_newline(self):
        self.assertEqual(l10n_check.joined("    First line\n    Second line"), "First line\nSecond line")

    def test_common_indentation_is_removed(self):
        self.assertEqual(l10n_check.joined("        Deeper\n    Shallow"), "    Deeper\nShallow")


class TranslationProblemsTests(unittest.TestCase):
    def test_a_missing_language_is_reported(self):
        problems = l10n_check.translation_problems(ENGLISH_AND_RUSSIAN, ["ru", "es"])
        self.assertEqual(len(problems), 1)
        self.assertIn("'Hello'", problems[0])
        self.assertRegex(problems[0], r"\bes\b")
        self.assertNotRegex(problems[0], r"\bru\b")

    def test_an_allowlisted_key_may_be_english_only(self):
        problems = l10n_check.translation_problems(ENGLISH_AND_RUSSIAN, ["ru", "es"], source_only=frozenset({"Hello"}))
        self.assertEqual(problems, [])

    def test_a_value_with_other_placeholders_is_reported(self):
        strings = {"%lld spots": {"localizations": {"ru": string_unit("%@ мест")}}}
        problems = l10n_check.translation_problems(strings, ["ru"])
        self.assertEqual(len(problems), 1)
        self.assertIn("'%@ мест'", problems[0])
        self.assertRegex(problems[0], r"\bru\b")

    def test_a_plural_variant_with_other_placeholders_is_reported(self):
        russian = plural(one="%lld место", few="%@ места", many="%lld мест")
        strings = {"%lld spots": {"localizations": {"ru": russian}}}
        problems = l10n_check.translation_problems(strings, ["ru"])
        self.assertEqual(len(problems), 1)
        self.assertIn("'%@ места'", problems[0])

    def test_a_complete_entry_has_no_problems(self):
        strings = {"%lld spots": {"localizations": {
            "en": plural(one="%lld spot", other="%lld spots"),
            "ru": plural(one="%lld место", few="%lld места", many="%lld мест", other="%lld места"),
        }}}
        self.assertEqual(l10n_check.translation_problems(strings, ["ru"]), [])

    def test_the_catalog_name_is_in_the_message(self):
        strings = {"NSCameraUsageDescription": {"localizations": {"en": string_unit("To take a photo")}}}
        problems = l10n_check.translation_problems(strings, ["ru"], catalog="InfoPlist.xcstrings")
        self.assertEqual(len(problems), 1)
        self.assertIn("InfoPlist.xcstrings", problems[0])


class LiteralProblemsTests(unittest.TestCase):
    def test_a_literal_matching_no_key_is_reported(self):
        problems = l10n_check.literal_problems({"Join": {}}, {"Join": {SOURCE}, "Leave": {SOURCE}})
        self.assertEqual(len(problems), 1)
        self.assertIn('localized("Leave")', problems[0])
        self.assertIn(str(SOURCE), problems[0])

    def test_a_literal_matching_two_keys_is_reported(self):
        problems = l10n_check.literal_problems({"%lld spots": {}, "%@ spots": {}}, {"\\(n) spots": {SOURCE}})
        self.assertEqual(len(problems), 1)
        self.assertIn('localized("\\(n) spots")', problems[0])

    def test_an_unused_key_is_reported_unless_manual(self):
        strings = {"Join": {}, "Leave": {}, "Coming soon": {"extractionState": "manual"}}
        problems = l10n_check.literal_problems(strings, {"Join": {SOURCE}})
        self.assertEqual(len(problems), 1)
        self.assertIn("'Leave'", problems[0])


class UsageKeysTests(unittest.TestCase):
    def test_release_keys_and_debug_only_keys_are_told_apart(self):
        pbxproj = configuration(
            "Debug", INFOPLIST_KEY_NSCameraUsageDescription="a", INFOPLIST_KEY_NSLocalNetworkUsageDescription="b"
        ) + configuration("Release", INFOPLIST_KEY_NSCameraUsageDescription="a")
        self.assertEqual(
            l10n_check.usage_keys(pbxproj), ({"NSCameraUsageDescription"}, {"NSLocalNetworkUsageDescription"})
        )

    def test_a_key_in_both_configurations_is_not_debug_only(self):
        pbxproj = configuration("Debug", INFOPLIST_KEY_NSCameraUsageDescription="a") + configuration(
            "Release", INFOPLIST_KEY_NSCameraUsageDescription="a"
        )
        self.assertEqual(l10n_check.usage_keys(pbxproj), ({"NSCameraUsageDescription"}, set()))


class InfoPlistProblemsTests(unittest.TestCase):
    def test_a_release_usage_key_missing_from_the_catalog_is_reported(self):
        problems = l10n_check.infoplist_problems({}, {"NSCameraUsageDescription"}, set())
        self.assertEqual(len(problems), 1)
        self.assertIn("'NSCameraUsageDescription'", problems[0])

    def test_a_debug_only_usage_key_in_the_catalog_is_reported(self):
        strings = {"NSLocalNetworkUsageDescription": {}}
        problems = l10n_check.infoplist_problems(strings, set(), {"NSLocalNetworkUsageDescription"})
        self.assertEqual(len(problems), 1)
        self.assertIn("'NSLocalNetworkUsageDescription'", problems[0])

    def test_keys_present_as_the_configurations_set_them_pass(self):
        strings = {"NSCameraUsageDescription": {}}
        problems = l10n_check.infoplist_problems(
            strings, {"NSCameraUsageDescription"}, {"NSLocalNetworkUsageDescription"}
        )
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
