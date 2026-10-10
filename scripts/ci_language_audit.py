#!/usr/bin/env python3
"""Verify coverage of Turkish, Indonesian, Malay and other app languages per switch arm.

Unlike grep-based checks, this inspects every discriminant in a tuple switch.
This prevents a single missing state/language pair (the Oct 10 build failure)
from going unnoticed merely because a different state already mentions Malay.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {"russian", "english", "uzbek", "uzbekCyrillic", "turkish", "indonesian", "malay"}
LANG_PATTERN = r"(?:russian|english|uzbekCyrillic|uzbek|turkish|indonesian|malay)"
CASE_TUPLE = re.compile(
    r"\(\s*(\.[a-zA-Z_]\w*(?:\([^)]*\))?|\"[^\"]*\"|_|\w+)\s*,\s*"
    r"(\.[a-zA-Z_]\w*(?:\([^)]*\))?|\"[^\"]*\"|_|\w+)\s*\)"
)
SWITCH_TUPLE = re.compile(r"\bswitch\s*\(\s*([^,()]+)\s*,\s*([^,()]+)\s*\)\s*\{")
CASE_LINE = re.compile(r"(?m)^\s*case\s+([^\n]+?):")
DEFAULT_LINE = re.compile(r"(?m)^\s*(?:@unknown\s+)?default\s*:")

def tuple_switch_issues(source: str, path: str):
    issues = []
    switches = 0
    for match in SWITCH_TUPLE.finditer(source):
        operands = (match.group(1).strip(), match.group(2).strip())
        language_positions = [i for i, x in enumerate(operands) if x == "language" or x.endswith(".language")]
        if len(language_positions) != 1:
            continue
        pos = language_positions[0]
        depth = 1
        end = match.end()
        while end < len(source) and depth:
            depth += (source[end] == "{") - (source[end] == "}")
            end += 1
        if depth:
            issues.append(f"{path}: unterminated tuple switch")
            continue
        body = source[match.end():end-1]
        if DEFAULT_LINE.search(body):
            continue  # Explicitly defined fallback is exhaustive by construction.
        coverage = {}
        for line in CASE_LINE.findall(body):
            for a, b in CASE_TUPLE.findall(line):
                pair = (a, b)
                case_lang = pair[pos].lstrip(".")
                if case_lang not in LANGUAGES:
                    continue
                stage = pair[1-pos].split("(", 1)[0]
                coverage.setdefault(stage, set()).add(case_lang)
        if not coverage:
            continue  # Not a language-enum switch; may have another enum.
        switches += 1
        for stage, covered in coverage.items():
            missing = LANGUAGES - covered
            if missing:
                line_no = source.count("\n", 0, match.start()) + 1
                issues.append(f"{path}:{line_no}: {stage} missing " + ", ".join(sorted(missing)))
    return switches, issues


def check_files(root: Path):
    total = 0
    issues = []
    for path in sorted((root / "Sources").rglob("*.swift")):
        count, problems = tuple_switch_issues(path.read_text("utf-8"), str(path.relative_to(root)))
        total += count
        issues.extend(problems)
    # Ensure the app-wide language entry points exist before a new language is enabled.
    definitions = {
      "Sources/AppShell/AppSettingsStore.swift": ["case turkish = \"tr\"", "case indonesian = \"id\"", "case malay = \"ms\"", 'case .malay: return "ms_MY"'],
      "Sources/Core/AppLocalization.swift": ["language == .turkish", "language == .indonesian", "language == .malay", "MalayLocalization.key("],
      "Sources/Core/TurkishLocalization.swift": ["static func key(", "static func phrase("],
      "Sources/Core/IndonesianLocalization.swift": ["static func key(", "static func phrase("],
      "Sources/Core/MalayLocalization.swift": ["static func key(", "static func phrase("],
    }
    for rel, markers in definitions.items():
        path = root / rel
        if not path.is_file():
            issues.append(f"{rel} missing")
            continue
        s = path.read_text("utf8")
        for marker in markers:
            if marker not in s:
                issues.append(f"{rel}: missing {marker}")
    # Format keys used with String(format:...) must preserve argument types and
    # positions. Translators may reorder arguments only with %2$d / %1$@.
    app_copy = (root / "Sources/Core/AppLocalization.swift").read_text("utf8")
    turkish_copy = (root / "Sources/Core/TurkishLocalization.swift").read_text("utf8")
    try:
        english = app_copy.split('"en": [', 1)[1].split('"ru": [', 1)[0]
        keyed = turkish_copy.split('private static let byKey', 1)[1].split('private static let byPhrase', 1)[0]
    except IndexError:
        issues.append("Cannot extract the English/Turkish format-key dictionaries")
        return total, issues
    key_values = re.compile(r'"((?:\\.|[^"\\])*)"\s*:\s*"((?:\\.|[^"\\])*)"')
    english_values = dict(key_values.findall(english))
    turkish_values = dict(key_values.findall(keyed))
    placeholders = re.compile(r'%(?:(\d+)\$)?[-+ #0]*(?:\d+)?(?:\.\d+)?(?:hh|h|ll|l|z|t|j)?([@diufFeEgGxXoscCp])')
    def argument_signature(fmt):
        return sorted((int(pos) if pos else idx + 1, kind)
                      for idx, (pos, kind) in enumerate(placeholders.findall(fmt)))
    for key, target in turkish_values.items():
        source = english_values.get(key)
        if source is not None and argument_signature(source) != argument_signature(target):
            issues.append(f"Turkish placeholder types/order mismatch: {key}")
    return total, issues

if __name__ == "__main__":
    if "--self-test" in sys.argv:
        stage = """switch (self, language) {
          case (.checkingProvider(let name), .russian): return "r"
          case (.checkingProvider(let name), .english), (.checkingProvider(let name), .turkish), (.checkingProvider(let name), .indonesian), (.checkingProvider(let name), .uzbek), (.checkingProvider(let name), .uzbekCyrillic): return "x"
          case (.starting, .russian), (.starting, .english), (.starting, .turkish), (.starting, .indonesian), (.starting, .malay), (.starting, .uzbek), (.starting, .uzbekCyrillic): return "y"
        }"""
        count, defects = tuple_switch_issues(stage, "self-test.swift")
        assert count == 1 and len(defects) == 1 and '.checkingProvider missing malay' in defects[0], defects
        print("PASS: negative regression test detects missing (.checkingProvider, .malay)")
        sys.exit(0)
    count, problems = check_files(ROOT)
    if problems:
        for p in problems:
            print("LANGUAGE AUDIT ERROR:", p)
        sys.exit(1)
    print(f"LANGUAGE AUDIT PASS: {count} tuple switches verified; TR, ID and MS registration checked")
