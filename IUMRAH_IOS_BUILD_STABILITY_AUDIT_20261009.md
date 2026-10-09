# iumrah iOS build stability audit — 2026-10-09

## Input
- `kepler-ios-main 5.zip` source snapshot
- `logs_102836254470.zip` GitHub Actions failed simulator build

## Root cause, proven from the failing Xcode log
Xcode reported 9 errors (3 Swift compilation units): `AppSettingsStore.Language` did not include `.indonesian`, and `IndonesianLocalization` did not exist, while screens referenced both. This stopped `Validate simulator build` before the archive/signing phase.

## Corrections
- Registered Indonesian as a real application language (`id` / `id_ID`), added its localization implementation and enabled the explicit-selection UI and Umrah Guide mapping.
- Added exhaustive Indonesian handling to all application-language switches. Existing Turkish/English/Russian/Uzbek branches were not removed; the older English-only copy uses a safe fallback where an Indonesian translation has not yet been authored.
- Fixed actor-isolation initialization warnings in `HotelImageCache` without changing cache limits, disk directory, or request behavior.
- Removed two unused imagesets' orphaned JPG files in the audited full-repository copy; the ZIP patch bot cannot delete old files, so these warnings may remain until those two orphaned files are manually deleted.
- Corrected two `.png` resources that actually had JPEG binary contents, preserving their image dimensions and visible designs.
- Added `scripts/ci_preflight.py` and early preflight to the iOS and Mac TestFlight workflow files in the full repository copy. **The ZIP patch bot deliberately blocks changes to `.github/workflows/testflight*.yml`**: the workflow edits must be installed manually from the separate optional workflow ZIP.

## Local validation
- All 262 Swift files passed `swiftc -frontend -parse` (syntax only; no Apple SDK typecheck available).
- SwiftSyntax audited 443 app-language switches; no switch remained without Indonesian handling (or a default branch).
- `scripts/ci_preflight.py` passed.
- Backend/PackageEngine: TypeScript `tsc --noEmit` passed.
- Backend/PackageEngine: 122 regular tests + 24 runtime tests passed (146/146).
- All workflow YAML parsed without error.
- iOS and Widgets provisioning profiles are valid until August 23, 2027 (this does not check local signing private keys/Apple account restrictions).

## Limits and remaining release gates
1. **No macOS/Xcode here**: a real `xcodebuild build`, archive, signing and TestFlight delivery are NOT verified. Run the iOS `TestFlight` workflow after applying the patch; inspect its complete log. Do not claim zero future build failures until that workflow succeeds.
2. The provided snapshot still does not have fully translated Indonesian UI copy throughout all view-local strings. English fallback is used in older content. This is a localization completeness issue, not a Swift build blocker.
3. The separate **TestFlight Mac** workflow references a missing `Resources/Provisioning/iumrah_Mac_App_Store.provisionprofile` in the provided snapshot. It cannot complete Mac code signing unless the corresponding Apple Mac App Store profile is supplied. iOS signing uses different existing profiles.
4. GitHub Actions secrets, Apple distribution signing certificate, network and App Store Connect upload can only be verified on the actual GitHub runner.
5. Two legacy unassigned images remain after applying the **patch ZIP** (because the existing ZIP workflow copies files but does not delete). They are non-fatal actool warnings.

## Patch bot instructions
Upload `iumrah-beta-update-20261009-build-stability.zip` at the repository root on `main`. The existing apply-update workflow will extract the included relative paths. Do **not** include an extra top-level folder. Trigger `TestFlight` after the patch commit is present.

For early CI diagnostics, manually replace the two protected workflow YAML files from the separately provided workflow ZIP at their original repository paths. This is optional for the immediate compile fix, but recommended to prevent future late failures.
