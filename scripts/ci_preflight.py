#!/usr/bin/env python3
"""Fast, dependency-free, non-signing checks before starting XcodeGen/TestFlight.

This is a guardrail, not a substitute for an actual Xcode build and device QA.
"""
from pathlib import Path
import json
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []


def require(condition, message):
    if not condition:
        errors.append(message)


sources = sorted((ROOT / 'Sources').rglob('*.swift'))
widgets = sorted((ROOT / 'WidgetExtension').rglob('*.swift'))
require(bool(sources) and bool(widgets), 'Sources or widgets Swift files missing')

# Parse every Swift source (including excluded/legacy sources) before dependencies
# are downloaded. -parse deliberately does not require UIKit or Apple SDKs.
compiler = shutil.which('swiftc')
require(compiler is not None, 'swiftc unavailable')
if compiler:
    result = subprocess.run(
        [compiler, '-frontend', '-parse', *map(str, sources + widgets)],
        cwd=ROOT, text=True, capture_output=True, check=False
    )
    require(result.returncode == 0, 'Swift syntax parse failed:\n' + result.stderr[-6000:])

settings_file = ROOT / 'Sources/AppShell/AppSettingsStore.swift'
settings = settings_file.read_text(encoding='utf-8') if settings_file.exists() else ''
match = re.search(r'\benum\s+Language\s*:\s*String\s*,.*?\{(.*?)\n\s*var id:', settings, re.S)
require(match is not None, 'AppSettingsStore.Language enum missing')
if match:
    case_values = dict(re.findall(r'\bcase\s+(\w+)\s*=\s*"([^"]+)"', match.group(1)))
    expected = {
        'russian': 'ru', 'english': 'en', 'uzbek': 'uz',
        'uzbekCyrillic': 'uz-cyrl', 'turkish': 'tr', 'indonesian': 'id'
    }
    for name, code in expected.items():
        require(case_values.get(name) == code, f'Language.{name} absent or incorrect language code')
    require(len(set(case_values.values())) == len(case_values), 'Duplicate language codes')

for name in ['TurkishLocalization', 'IndonesianLocalization']:
    p = ROOT / f'Sources/Core/{name}.swift'
    require(p.is_file() and f'enum {name}' in p.read_text(encoding='utf-8'),
            f'Missing {name} implementation')

for name in ['Sources/AppShell/IumrahLanguageSelectionSheet.swift',
             'Sources/Core/AppLocalization.swift']:
    path = ROOT / name
    require(path.exists() and '.indonesian' in path.read_text(encoding='utf-8'),
            f'Indonesian language was not wired into {name}')

p = ROOT / 'Resources/Info.plist'
try:
    with p.open('rb') as f:
        info = plistlib.load(f)
    require(info.get('CFBundleIdentifier') == '$(PRODUCT_BUNDLE_IDENTIFIER)',
            'Unexpected app bundle identifier in Info.plist')
except (OSError, ValueError, TypeError) as exc:
    errors.append(f'Invalid Info.plist: {exc}')

for base in (ROOT / 'Resources/Assets.xcassets', ROOT / 'WidgetExtension/Assets.xcassets'):
    require(base.is_dir(), f'Missing asset catalogue: {base}')
    if not base.is_dir():
        continue
    for contents in base.rglob('Contents.json'):
        try:
            content = json.loads(contents.read_text(encoding='utf-8'))
        except (OSError, ValueError) as exc:
            errors.append(f'Invalid asset JSON: {contents}: {exc}')
            continue
        files = [entry['filename'] for key in ('images', 'data')
                 for entry in content.get(key, [])
                 if isinstance(entry, dict) and entry.get('filename')]
        for filename in files:
            asset = contents.parent / filename
            require(asset.is_file(), f'Missing asset referenced by {contents}: {filename}')
            if asset.is_file() and asset.suffix.lower() == '.png':
                require(asset.open('rb').read(8) == b'\x89PNG\r\n\x1a\n',
                        f'Image declared as PNG has wrong file format: {asset}')
        if contents.parent.name.endswith('.imageset'):
            declared = set(files)
            for asset in contents.parent.iterdir():
                if asset.is_file() and asset.name != 'Contents.json' and asset.name not in declared:
                    # The legacy ZIP patch bot copies files but cannot delete
                    # obsolete files; these actool notices are non-fatal.
                    print(f'WARNING: unassigned image asset: {asset}')

if errors:
    print('Repository preflight FAILED:')
    for e in errors:
        print(' - ' + e)
    sys.exit(1)

print(f'Preflight PASS: {len(sources)} app Swift + {len(widgets)} widget Swift files, language registry, plists, asset catalogues.')
