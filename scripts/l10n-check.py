#!/usr/bin/env python3
"""Keeps the code and Localizable.xcstrings in step: every `localized("...")` literal in lily/ must be a key of the
catalog, every key must be used by the code (or marked manual), every key must be translated into every language the
app ships, and every value (the English plural forms included) must carry the key's placeholders. Run by
./scripts/ci.sh lint; exits 1 with one line per problem."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "lily" / "Localizable.xcstrings"
SOURCES = ROOT / "lily"
# The languages the app ships (AppLanguage.allCases) besides the source language.
LANGUAGES = ["ru", "es", "fr", "uk", "pl", "pt"]
LITERAL = re.compile(r'localized\("(?!"")((?:[^"\\]|\\.)*)"')
MULTILINE = re.compile(r'localized\("""\n(.*?)\n[ \t]*"""', re.DOTALL)
INTERPOLATION = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|lf|f|s)")


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


def main():
    problems = []
    strings = json.loads(CATALOG.read_text())["strings"]
    used = set()
    for literal, files in literals().items():
        matches = [key for key in strings if pattern(literal).match(key)]
        if len(matches) != 1:
            where = ", ".join(sorted(str(f) for f in files))
            problems.append(f"{where}: localized(\"{literal}\") matches {len(matches)} catalog keys")
        used.update(matches)
    for key, entry in strings.items():
        if key not in used and entry.get("extractionState") != "manual":
            problems.append(f"catalog key not used by the code: {key!r}")
        localizations = entry.get("localizations", {})
        for language in LANGUAGES:
            if language not in localizations:
                problems.append(f"{key!r}: no {language} translation")
        for language, localization in localizations.items():
            for value in values(localization):
                if placeholders(value) != placeholders(key):
                    problems.append(f"{key!r}: {language} value {value!r} has other placeholders than the key")
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
