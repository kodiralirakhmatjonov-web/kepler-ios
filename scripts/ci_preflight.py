#!/usr/bin/env python3
"""Fast fail-closed iOS repository checks; a real Xcode build is still required.

No third-party dependencies. Run before XcodeGen on the macOS GitHub runner.
"""
from __future__ import annotations

from pathlib import Path
import json
import plistlib
import re
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []
warnings: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def content(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        errors.append(f"Unreadable file {path.relative_to(ROOT)}: {exc}")
        return ""


def repo(path: str) -> Path:
    return ROOT / path


swift_files = sorted(repo("Sources").rglob("*.swift")) + sorted(repo("WidgetExtension").rglob("*.swift"))
check(len(swift_files) >= 250, f"Unexpected number of Swift sources: {len(swift_files)}")
compiler = shutil.which("swiftc")
check(bool(compiler), "Swift compiler missing (run on macOS-26 Xcode runner)")
if compiler:
    # Parse in one invocation; this tests syntax, not symbol/type resolution.
    result = subprocess.run([compiler, "-frontend", "-parse", *map(str, swift_files)],
                            text=True, capture_output=True, check=False)
    check(result.returncode == 0, "Swift parse failed:\n" + result.stderr[-8000:])

settings = content(repo("Sources/AppShell/AppSettingsStore.swift"))
enum = re.search(r"\benum\s+Language\s*:\s*String\s*,[^\{]*\{(.*?)\n\s*var id:", settings, re.S)
check(bool(enum), "AppSettingsStore.Language enum is missing")
expected = {
    "russian": "ru", "english": "en", "turkish": "tr", "indonesian": "id",
    "malay": "ms", "uzbek": "uz", "uzbekCyrillic": "uz-cyrl",
}
if enum:
    cases = re.findall(r"\bcase\s+(\w+)\s*=\s*\"([^\"]+)\"", enum.group(1))
    found = dict(cases)
    check(len(found) == len(cases), "Duplicate Language enum case")
    for name, code in expected.items():
        check(found.get(name) == code, f"Missing/mismatched Language.{name} = {code}")
    check(len(set(found.values())) == len(found), "Duplicate Language raw values")
    check('case .malay: return "ms_MY"' in settings, "Missing Malay locale ms_MY")

for type_name in ("TurkishLocalization", "IndonesianLocalization", "MalayLocalization"):
    file = repo(f"Sources/Core/{type_name}.swift")
    check(file.is_file(), f"Missing implementation {file.relative_to(ROOT)}")
    if file.is_file():
        check(bool(re.search(rf"\benum\s+{type_name}\s*\{{", content(file))),
              f"Missing enum {type_name}")
for name in ("Sources/AppShell/IumrahLanguageSelectionSheet.swift",
             "Sources/Umrah Flow/Components/UmrahLanguagesSheet.swift"):
    check(".malay" in content(repo(name)), f"Malay not connected to {name}")

# Detect newly added languages that would create nonexhaustive Swift switches.
# A guardrail only; compiler semantic exhaustiveness remains the authority.
check_count = 0
missing_switches = []
for file in swift_files:
    source = content(file)
    for match in re.finditer(r"\bswitch\s+[^\n\{]{1,150}\s*\{", source):
        i, depth = match.end(), 1
        while i < len(source) and depth:
            if source[i] == "{":
                depth += 1
            elif source[i] == "}":
                depth -= 1
            i += 1
        block = source[match.end():i-1]
        # The same family of branches must handle all app languages, unless
        # the switch intentionally has an explicit default or unknown case.
        if re.search(r"\bcase\b[^\n]*\.indonesian\b", block) and re.search(r"\bcase\b[^\n]*\.english\b", block):
            check_count += 1
            if not re.search(r"\bcase\b[^\n]*\.malay\b", block) and not re.search(r"\b(?:default|@unknown default)\s*:", block):
                missing_switches.append(f"{file.relative_to(ROOT)}:{source.count(chr(10), 0, match.start())+1}")
check(not missing_switches, "Language switches missing Malay:\n" + "\n".join(missing_switches[:40]))

for p in (repo("Resources/Info.plist"), repo("WidgetExtension/Info.plist"),
          repo("Resources/iUmra.entitlements"), repo("WidgetExtension/iUmraWidgets.entitlements")):
    try:
        with p.open("rb") as stream:
            info = plistlib.load(stream)
        check(isinstance(info, dict), f"Not a plist dictionary: {p}")
        if p.name == "Info.plist":
            check(info.get("CFBundleIdentifier") == "$(PRODUCT_BUNDLE_IDENTIFIER)",
                  f"Bundle identity changed in {p.relative_to(ROOT)}")
    except (OSError, TypeError, ValueError) as exc:
        errors.append(f"Invalid plist {p.relative_to(ROOT)}: {exc}")

project = content(repo("project.yml"))
for bundle_id in ("com.iumrah.app", "com.iumrah.app.widgets"):
    check(f"PRODUCT_BUNDLE_IDENTIFIER: {bundle_id}" in project, f"Missing bundle ID {bundle_id}")
for locale in ("en", "ru", "uz", "uz-Cyrl", "tr", "id", "ms"):
    check(repo(f"Resources/{locale}.lproj").is_dir(), f"Missing localization Resources/{locale}.lproj")

png_header = b"\x89PNG\r\n\x1a\n"
asset_count = 0
for folder in (repo("Resources/Assets.xcassets"), repo("WidgetExtension/Assets.xcassets")):
    check(folder.is_dir(), f"Asset catalogue missing: {folder.relative_to(ROOT)}")
    if not folder.is_dir():
        continue
    for contents in folder.rglob("Contents.json"):
        asset_count += 1
        try:
            meta = json.loads(content(contents))
            check(isinstance(meta, dict), f"Unexpected asset JSON: {contents.relative_to(ROOT)}")
        except ValueError as exc:
            errors.append(f"Invalid asset JSON {contents.relative_to(ROOT)}: {exc}")
            continue
        if not isinstance(meta, dict):
            continue
        declared = set()
        for key in ("images", "data", "colors"):
            for entry in meta.get(key, []):
                if not isinstance(entry, dict):
                    continue
                filename = entry.get("filename")
                if not filename:
                    continue
                declared.add(filename)
                p = contents.parent / filename
                check(p.is_file(), f"Missing asset {p.relative_to(ROOT)}")
                if p.is_file() and p.suffix.lower() == ".png":
                    check(p.open("rb").read(8) == png_header, f"PNG has invalid header: {p.relative_to(ROOT)}")
                if p.is_file() and p.suffix.lower() in (".jpg", ".jpeg"):
                    check(p.open("rb").read(3) == b"\xff\xd8\xff", f"JPEG has invalid header: {p.relative_to(ROOT)}")
        if contents.parent.name.endswith(".imageset"):
            for entry in contents.parent.iterdir():
                if entry.is_file() and entry.name not in declared and entry.name != "Contents.json":
                    warnings.append(f"Unassigned asset: {entry.relative_to(ROOT)}")

for path in (repo("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"),):
    check(path.is_file(), "Missing primary 1024x1024 icon")
    if path.is_file():
        data = path.open("rb").read(24)
        check(data[:8] == png_header and len(data) == 24 and struct.unpack(">II", data[16:24]) == (1024, 1024),
              "Primary AppIcon must be an actual 1024x1024 PNG")

# The original Malay guard only checked whether Malay existed somewhere in a
# switch; it missed (.checkingProvider, .malay) in a tuple switch. Run the
# stricter per-case language matrix audit before accepting the patch.
result = subprocess.run([sys.executable, str(repo("scripts/ci_language_audit.py"))],
                        cwd=ROOT, capture_output=True, text=True, check=False)
check(result.returncode == 0,
      "Language matrix audit failed:\n" + (result.stdout + result.stderr)[-8000:])

for warning in warnings:
    print("WARNING:", warning)
if errors:
    print("PREFLIGHT FAILED:")
    for error in errors:
        print(" -", error)
    sys.exit(1)
print(f"PREFLIGHT PASS: {len(swift_files)} Swift files parsed, {check_count} language switches checked, "
      f"{asset_count} assets and plists validated. Real Xcode compile still required.")
