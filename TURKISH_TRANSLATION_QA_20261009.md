# Turkish localization v2 — release QA snapshot

Source repository: `kepler-ios-main 4.zip` (original untouched). Standalone cumulative update; not dependent on Turkish v1.

| Check | Result |
|---|---|
| Original central strings + Turkish language label | 553/553 |
| English–Turkish phrase catalogue | 2546 entries |
| Literal 4-language call-site coverage (`tr`, `localized`, `localizedFinal`, `localizedDetail`, `copy.text`, `text`) | 1775/1775 |
| Direct `TurkishLocalization.phrase` literal references | 431 checked (one empty); no unhandled string |
| Indirect `FlowCopy.en(...)` entries | 57/57 |
| eSIM copy keys | 37/37 |
| Language switch candidates | 414/414 include `turkish` |
| Swift string-interpolation argument mismatches | 0 |
| Central printf-format argument mismatches | 0 |
| Swift parse, full source tree | 253/253 parsed |
| Standalone translator typecheck + runtime | Passed with Swift 6.2.1 Linux |
| Native Xcode build, UI screenshots on iPhone | Not performed; macOS/Xcode unavailable |
| Native-speaker Turkish proofreading | Recommended before store release |

The static checks cover recognized localization mechanisms. Content supplied by backend APIs and every possible text drawn at runtime cannot be exhaustively validated by source inspection alone. Do not promote to App Store without a successful iOS CI build and Turkish-language TestFlight QA.
