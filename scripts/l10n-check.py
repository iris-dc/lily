#!/usr/bin/env python3
"""Keeps the code and the two string catalogs in step. Localizable.xcstrings: every `localized("...")` literal in
lily/ must be a key of the catalog, every key must be used by the code (or marked manual), every key must be
translated into every language the app ships, and every value (the English plural forms included) must carry the
key's placeholders. InfoPlist.xcstrings: every usage description the Release configuration sets (an
`INFOPLIST_KEY_NS...UsageDescription` build setting, since Info.plist is generated) must be in the catalog in every
language, the brand keys stay English alone, and a usage description that only the Debug configuration sets must not
be in it, because a development-only permission string must not ship. Run by ./scripts/ci.sh lint; exits 1 with one
line per problem. The checks are functions over data (a catalog's `strings`, the literals, the pbxproj text) so a
test can hand them fixtures; the pbxproj is read, never written."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "lily" / "Localizable.xcstrings"
INFOPLIST_CATALOG = ROOT / "lily" / "InfoPlist.xcstrings"
PBXPROJ = ROOT / "lily.xcodeproj" / "project.pbxproj"
SOURCES = ROOT / "lily"
# The languages the app ships (AppLanguage.allCases) besides the source language.
LANGUAGES = ["ru", "es", "fr", "uk", "pl", "pt"]
# The brand, English alone by design: the name is the name in every language.
BRAND_KEYS = frozenset({"CFBundleDisplayName", "CFBundleName"})
LITERAL = re.compile(r'localized\("(?!"")((?:[^"\\]|\\.)*)"')
MULTILINE = re.compile(r'localized\("""\n(.*?)\n[ \t]*"""', re.DOTALL)
INTERPOLATION = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|lf|f|s)")
USAGE_KEY = re.compile(r"INFOPLIST_KEY_(NS\w+UsageDescription)")
# One XCBuildConfiguration's settings with the configuration they belong to.
BUILD_CONFIGURATION = re.compile(r"buildSettings = \{(.*?)\};\s*name = (Debug|Release);", re.DOTALL)


def literals():
    found = {}
    for path in SOURCES.rglob("*.swift"):
        if path.name == "Localized.swift":
            continue
        text = path.read_text()
        for match in LITERAL.finditer(text):
            found.setdefault(match.group(1), set()).add(path.relative_to(ROOT))
        for match in MULTILINE.finditer(text):
            found.setdefault(joined(match.group(1)), set()).add(path.relative_to(ROOT))
    return found


def joined(block):
    """A multi-line literal as Swift reads it: the common indentation gone, a trailing backslash joining lines."""
    lines = block.split("\n")
    indent = min(len(line) - len(line.lstrip()) for line in lines if line.strip())
    text = ""
    for line in lines:
        line = line[indent:]
        text += line[:-1] if line.endswith("\\") else line + "\n"
    return text.removesuffix("\n")


def pattern(literal):
    """A code literal as a regex over catalog keys: an interpolation stands for one placeholder of any type."""
    parts = INTERPOLATION.split(literal)
    escaped = [re.escape(part.replace('\\"', '"').replace("\\\\", "\\")) for part in parts]
    return re.compile("^" + PLACEHOLDER.pattern.join(escaped) + "$")


def placeholders(text):
    """The placeholders of a key or a value, positions dropped, so a reordered `%2$@ %1$@` still matches `%@ %@`."""
    return sorted(re.sub(r"\d+\$", "", p) for p in PLACEHOLDER.findall(text))


def values(localization):
    if "stringUnit" in localization:
        yield localization["stringUnit"]["value"]
    for variant in localization.get("variations", {}).get("plural", {}).values():
        yield variant["stringUnit"]["value"]


def literal_problems(strings, literals):
    """Every literal matches exactly one key, and every key is matched by a literal unless marked manual."""
    problems = []
    used = set()
    for literal, files in literals.items():
        matches = [key for key in strings if pattern(literal).match(key)]
        if len(matches) != 1:
            where = ", ".join(sorted(str(f) for f in files))
            problems.append(f"{where}: localized(\"{literal}\") matches {len(matches)} catalog keys")
        used.update(matches)
    for key, entry in strings.items():
        if key not in used and entry.get("extractionState") != "manual":
            problems.append(f"catalog key not used by the code: {key!r}")
    return problems


def translation_problems(strings, languages, source_only=frozenset(), catalog="Localizable.xcstrings"):
    """Every key outside `source_only` has every language; every value present carries the key's placeholders."""
    problems = []
    for key, entry in strings.items():
        localizations = entry.get("localizations", {})
        if key not in source_only:
            for language in languages:
                if language not in localizations:
                    problems.append(f"{catalog}: {key!r}: no {language} translation")
        for language, localization in localizations.items():
            for value in values(localization):
                if placeholders(value) != placeholders(key):
                    problems.append(
                        f"{catalog}: {key!r}: {language} value {value!r} has other placeholders than the key"
                    )
    return problems


def usage_keys(pbxproj_text):
    """The usage descriptions the configurations set: those of any Release block, and those of Debug blocks only."""
    release, debug = set(), set()
    for match in BUILD_CONFIGURATION.finditer(pbxproj_text):
        settings, configuration = match.groups()
        (release if configuration == "Release" else debug).update(USAGE_KEY.findall(settings))
    return release, debug - release


def infoplist_problems(strings, release_keys, debug_only_keys):
    """A usage description that ships is in the catalog; one that only development sets is not."""
    problems = []
    for key in sorted(release_keys - strings.keys()):
        problems.append(f"InfoPlist.xcstrings lacks {key!r}, a usage description the Release configuration sets")
    for key in sorted(debug_only_keys & strings.keys()):
        problems.append(
            f"InfoPlist.xcstrings carries {key!r}, which only the Debug configuration sets; "
            "a development-only permission string must not ship"
        )
    return problems


def main():
    strings = json.loads(CATALOG.read_text())["strings"]
    info = json.loads(INFOPLIST_CATALOG.read_text())["strings"]
    problems = (
        literal_problems(strings, literals())
        + translation_problems(strings, LANGUAGES)
        + translation_problems(info, LANGUAGES, source_only=BRAND_KEYS, catalog="InfoPlist.xcstrings")
        + infoplist_problems(info, *usage_keys(PBXPROJ.read_text()))
    )
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
