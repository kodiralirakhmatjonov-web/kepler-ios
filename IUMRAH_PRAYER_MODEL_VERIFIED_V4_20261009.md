# iumrah Prayer Times — Verified model hotfix V4

Purpose: resolve current GitHub main mismatch. The IumrahPrayerTimesView.swift currently uses earlyReminderMinutes but IumrahPrayerPreferences.swift in main does not declare it.

This patch replaces only Sources/PrayerTimes/IumrahPrayerPreferences.swift. It includes:
- Optional earlyReminderMinutes for old saved settings compatibility.
- Scheduling 5/10/15/30 minute early notifications without altering booking/flight notification identifiers.

No UI, layout, other service, resources, or project/workflow files changed.

HOW TO VERIFY APPLICATION BEFORE TESTFLIGHT:
1. Upload THIS ZIP to main of kodiralirakhmatjonov-web/kepler-ios and commit.
2. In Actions, wait until a NEW 'Apply iumrah Beta ZIP update' run is successful, after upload.
3. Open Sources/PrayerTimes/IumrahPrayerPreferences.swift on GitHub in the main branch.
4. Confirm that this line exists: `var earlyReminderMinutes: Int? = nil`
5. Only THEN launch the TestFlight workflow on the updated main commit.

If the line does not exist, the patch was not applied. Do not run TestFlight yet. Inspect the Apply iumrah Beta ZIP update log / archive name.

Known limitation: Linux can only Swift parse; full Apple SDK typecheck and Xcode build require macOS. No claim of successful Xcode build is made.
