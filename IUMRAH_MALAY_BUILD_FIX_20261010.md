# Fix for build log 102884640666

Source basis: kepler-ios-main 5.zip + two previous incremental build patches.

Latest CI shows 39 `.malay` unknown-member errors in HotelsHomeView.swift; this archive **deliberately does not replace that file**, preserving Malay text added there since the prior archive.

Changes: AppSettingsStore.Language adds actual Malay `ms` case and ms_MY locale; exhaustive language switches updated in 83 Swift files; Malay choice appears in language picker; guide uses existing UmrahGuideLanguage.malay; duplicate Indonesian case patterns in previous patch corrected.

Caution: source files updated outside the supplied base archive could be overwritten by this file-replacement ZIP. Check changes before applying if newer edits exist. Genuine xcodebuild/TestFlight is required to confirm successful build; Linux Swift parse and stub typechecking do not prove the iOS target compiles.
