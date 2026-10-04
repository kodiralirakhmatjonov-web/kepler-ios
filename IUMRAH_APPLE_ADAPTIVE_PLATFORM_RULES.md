# iumrah Apple Adaptive Platform Rules

This repository ships one SwiftUI product with three native-feeling presentations:

- **iPhone** — compact, touch-first, bottom tabs + the existing drawer. The established phone layout is the visual regression baseline.
- **iPad** — responsive to the *current window*, not the device model. Uses native split navigation at regular widths, supports portrait/landscape, Split View and Stage Manager, and never stretches phone cards edge-to-edge.
- **Mac (Mac Catalyst)** — optimized Mac idiom (`TARGETED_DEVICE_FAMILY=6` for the Catalyst SDK), resizable window, persistent sidebar where appropriate, keyboard navigation, pointer/hover behavior from system controls, and readable content widths.

## Non-negotiable implementation rules

1. Never branch feature layout on a hard-coded iPad model or `UIScreen.main.bounds`. Resolve layout from the current container width and size class.
2. Compact iPhone branches remain structurally identical unless a phone-specific change is explicitly requested. Large-screen work belongs behind the adaptive environment.
3. Re-resolve layout inside a `NavigationSplitView` detail column. The outer window width is not the content width once a sidebar is visible.
4. Prefer native SwiftUI navigation, lists, toolbars, menus, buttons, sheets, context menus, pointer behavior and Liquid Glass APIs. Do not fake desktop chrome.
5. Long-form content uses a readable maximum width. Wide canvases earn their space with columns, grids, master/detail or maps; they are not simply widened.
6. Immersive map/journey experiences may hide the app sidebar while active and must restore it when exiting.
7. Mac device sessions must identify themselves as macOS/Catalyst and must never be labeled as iPhone Simulator.
8. Any new large-screen branch must keep touch targets, Dynamic Type, VoiceOver labels, RTL/localization and reduced-motion behavior intact.

## Layout classes

`IumrahAdaptiveLayout` is the single source of truth:

- compact: narrow windows / iPhone presentation
- regular: medium iPad-style content
- wide: large iPad content capable of selective multi-column composition
- desktop: Mac Catalyst; wide feature composition only when the actual detail canvas is sufficiently wide

Feature code should consume `@Environment(\.iumrahAdaptiveLayout)` instead of inventing local breakpoints.

## Navigation contract

- Compact: existing `TabView` + existing drawer.
- Regular / wide / desktop: `NavigationSplitView` + system sidebar.
- Root page hamburger is hidden when the sidebar is already visible.
- Mac keyboard commands: ⌘1 Home, ⌘2 Hotels, ⌘3 Trips, ⌘4 Care, ⌘5 Account, ⇧⌘N Notifications.

## Required visual QA matrix

Before release, capture and compare screenshots for at least:

- iPhone 13 mini / compact-width phone
- iPhone 11-class phone
- current large iPhone
- iPad mini portrait + landscape
- 11-inch iPad portrait + landscape
- 13-inch iPad landscape
- iPad Stage Manager / Split View at narrow, medium and full widths
- Mac window at minimum supported size (900×640), ~1024 pt, ~1280 pt, and a large desktop width
- Light + Dark appearance for each representative class

The review must cover Home, Hotels, Trip Builder, Final Package, Bookings/Booking Detail, Care, Account/Security/Active Sessions, Ziyarats, onboarding, modal sheets and navigation transitions.

## Release gates

- All Swift files parse.
- XcodeGen YAML parses.
- iOS simulator build passes.
- Mac Catalyst `generic/platform=macOS,variant=Mac Catalyst` build passes with code signing disabled in CI.
- Production archive continues to use the iOS App Store profile; Mac distribution provisioning must be configured separately in Apple Developer/App Store Connect before shipping the Mac binary.
