# iumrah iOS — Prayer Times build fix (2026-10-09)

## Source: GitHub Actions `logs_102722495614.zip`

Fixed both root causes in `iUmra` target:

1. Added future-proof AppSettingsStore.Language fallback to eliminate both `switch must be exhaustive` compiler errors after `.turkish` was introduced.
2. Moved `prayerText(...)` to a single internal (module-visible) implementation in `IumrahPrayerWallpaper.swift`, eliminating 14 cross-file `private` access errors.

Turkish translations provided for the 66 Prayer Times + Wallpaper screen text keys, falling back to English for future unsupported languages.

Other source files, UI layouts, WidgetKit target, and production configuration are untouched.

Checks: `swiftc -frontend -parse` passed, isolated strict Swift typechecking passed, localization assertions passed. Xcode build requires a macOS GitHub runner.

Apply by placing `iumrah-beta-update-buildfix-prayer-locales-20261009.zip` at the repository root on `main`; the existing apply-beta-update workflow watches the `iumrah-beta-update-*.zip` filename pattern.
