# iumrah iOS — Prayer notifications Xcode type-checking fix

## Problem
GitHub Actions `logs_102731878184.zip` shows Xcode failing in `Sources/PrayerTimes/IumrahPrayerTimesView.swift` near the inline `Toggle`/`Binding` for `earlyReminderMinutes`:

`the compiler is unable to type-check this expression in reasonable time`

## Fix
Refactored `IumrahPrayerNotificationSheet` into small, typed SwiftUI subcomponents and extracted complex inline `Binding` expressions into dedicated properties/functions. Preserves notification offset, early reminders (5, 10, 15, 30 minutes), test notifications and save action.

## Installation
Incremental ZIP patch. Apply to the repository after `iumrah-ios-unified-hotels-booking-prayer-widgets-balance-20261009.zip` and `iumrah-beta-update-buildfix-prayer-locales-20261009.zip`. The previous patches need not be reapplied. Unpack at repository root, overwriting the single Swift file.

## Validation
- Swift parser passed on all 259 Swift source files after recreating the two preceding patches, plus this one.
- Full Apple Xcode compile is not available in this environment; verify in GitHub Actions.
