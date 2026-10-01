# iumrah Widgets — one-time Apple signing setup

The widget code is included in the app patch, but Apple requires a separate App ID and provisioning profile for every Widget Extension.

## 1. Create the Widget Extension App ID

In Apple Developer → Certificates, Identifiers & Profiles → Identifiers → +:

- Type: App IDs → App
- Description: `iumrah Widgets`
- Bundle ID: **Explicit** → `com.iumrah.app.widgets`

No App Group is required by this implementation. The app and widget share only a minimal private snapshot through the team's Keychain Sharing access group `2DQ678JTNG.com.iumrah.shared`.

## 2. Create the App Store provisioning profile

Create an **App Store Connect / Distribution** provisioning profile for `com.iumrah.app.widgets`.

Important: select the same Apple Distribution certificate used by the existing `com.iumrah.app` production profile, because the repository already contains the encrypted private key for that certificate.

Download the profile and add it to the repository `Signing/` directory, for example:

`Signing/iumrah_widgets_App_Store.mobileprovision`

Do not replace the existing app profile.

## 3. Replace the TestFlight workflow once

The existing TestFlight workflow only installs/signs `com.iumrah.app`. A ready widget-aware replacement is supplied separately as `iumrah-testflight-widgets.yml`.

Because the beta ZIP unpacker GitHub App does not have `workflows` permission, the workflow file cannot be included in an `iumrah-beta-update-*.zip` patch. Replace `.github/workflows/testflight.yml` manually in GitHub with the supplied file.

The updated workflow:

- discovers the existing app profile;
- discovers the new `com.iumrah.app.widgets` profile;
- installs both profiles;
- passes the widget profile name to XcodeGen/Xcode;
- includes both bundle IDs in ExportOptions.plist.

## Widget bundle

The extension adds five widgets:

1. Active Trip — Small / Medium / Large
2. Booking Status — Small / Medium
3. Planned Umrah — Small / Medium / Large
4. iumrah ID — Small / Medium with QR
5. Umrah Countdown — Lock Screen Inline / Circular / Rectangular

Widget taps deep-link into the corresponding iumrah screen. The main app refreshes the private widget snapshot when booking status/account state changes, when the app becomes active, and when a planned Umrah is created or edited.

## Widgets v2 Premium
The v2 patch keeps the same widget extension bundle ID, entitlements, provisioning requirements, deep links and shared snapshot architecture as v1. No new Apple capability is required if Widgets v1 signing was already configured.
