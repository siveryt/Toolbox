# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Toolbox is an open-source iOS app (SwiftUI) that bundles many small independent utilities ("tools") — dice, converters, network utilities, scanners, meters, etc. — behind a single navigable list. It ships alongside a watchOS companion app and a dice Home Screen widget.

## Build & Run

This is a pure Xcode project (`Toolbox.xcodeproj`), no CocoaPods/Fastlane. Dependencies are Swift Package Manager, resolved automatically by Xcode.

- Open in Xcode: `open Toolbox.xcodeproj`
- Schemes / targets: `Toolbox` (iOS app), `Toolbox WatchOS Watch App` (watchOS), `diceWidgetExtension` (widget).
- Command-line build example:
  ```bash
  xcodebuild -project Toolbox.xcodeproj -scheme Toolbox -destination 'generic/platform=iOS' build
  ```
- There is no functional test suite. `ToolboxUITests/` and `ToolboxWatchUITests/` only drive the apps for App Store screenshots — verify changes by running the app.
- Screenshots: `bundle exec fastlane screenshots` (lanes `capture`, `capture_watch`, `frame` in [fastlane/Fastfile](fastlane/Fastfile)). snapshot captures, frameit adds bezels/titles/background per [Framefile.json](fastlane/screenshots/Framefile.json); custom scripts go in [fastlane/hooks/](fastlane/hooks/README.md). The UI tests find menu rows by the accessibility identifier `tool.<icon>`. Languages are in the Snapfile; every language folder needs `title.strings` and `keyword.strings`, and Polish uses its own font (see `FONTS` in the Fastfile) because Arial Rounded lacks its letters. Run fastlane with `LANG=en_US.UTF-8`.
- App Store texts: [fastlane/metadata/](fastlane/metadata/) holds name, subtitle, keywords, description and release notes per App Store locale; `bundle exec fastlane upload_metadata` sends them to App Store Connect (en-US and de-DE have no `name.txt`, so their store name stays as it is).
- `Buildnumber.xcconfig` (holds `BUILD_NUMBER` / `LAST_UPDATE`) and the `AppStore/` directory are git-ignored; `CURRENT_PROJECT_VERSION` reads `$(BUILD_NUMBER)` from that file, so a clean checkout may need it present to build the Release config.

## Architecture

### Tool registration is index-based — this is the most important gotcha

Every iOS tool is a SwiftUI `View` living in `Toolbox/Functions/`. Tools are registered by appending to the `toollist` array in [ContentView.swift](Toolbox/Mainscreen/ContentView.swift). Each entry is a `Tool` struct: `Tool(view: AnyView(SomeView()), title: NSLocalizedString(...), icon: "<SF Symbol name>")`.

Critically, **the app persists a user's custom order and hidden tools as integer indices into this array** (`@AppStorage("cvOrder")`, `@AppStorage("cvHidden")`). Consequences:

- **Add new tools by appending to the end of `toollist`.** Inserting or reordering entries shifts every following index and silently corrupts existing users' saved order and hidden state.
- The `icon` is an SF Symbol name rendered via `Label(..., systemImage:)`.
- There is no plugin/registry abstraction — the array is the single source of truth for the main menu.

### App entry & global wiring

[ToolboxApp.swift](Toolbox/ToolboxApp.swift) is the `@main` app. It injects, for the whole view tree:
- Core Data context (`SBDataController.container.viewContext`) — see persistence below.
- SwiftData `modelContainer(for: [WOLDevice.self])`.
- WhatsNewKit environment + `.whatsNewSheet()`.
- TipKit configuration.

### Two coexisting persistence systems

The app mixes two Apple persistence stacks; pick the one already used by the feature you touch:
- **Core Data** for scanned barcodes: [SBDataController](Toolbox/DataModels/ScannedBarcodes/Controller.swift) wraps `NSPersistentContainer(name: "ScannedBarcodes")` and is the standard CRUD path (`addBarcode`, `resetBarcodes`).
- **SwiftData** for Wake-on-LAN devices: [WOLDevice](Toolbox/Swift Data/WOL.swift) is an `@Model` class.

Most simple tools persist their own transient state directly with `@AppStorage` (UserDefaults) rather than a database — see the pattern in tools like [RomanConverter.swift](Toolbox/Functions/RomanConverter.swift).

### Shared helpers

[Extensions.swift](Toolbox/Helper/Extensions.swift) holds cross-cutting utilities used by many tools: share-sheet helpers (`shareFromView`/`shareFromSheet`), top-view-controller lookup (`Coordinator`), custom `EnvironmentValues` (`showingSheet`, `copyToast`, `showingInt`), and `AVMetadataObject.ObjectType.friendlyName` for the barcode scanner. Reach for these before writing new UIKit-bridging code.

### Cross-platform sharing

The watchOS app ([Toolbox WatchOS Watch App/](Toolbox WatchOS Watch App/)) and the widget ([diceWidget/](diceWidget/)) are separate targets with their own `ContentView`/entry points. Some tools (Dice, Counter, Random Number) exist as parallel, simpler reimplementations there rather than shared code — changing the iOS version does not automatically update the watch version.

### App icons

The icons are Icon Composer files in [Toolbox/Icons/](Toolbox/Icons/). `Toolbox.icon` is the primary icon (iOS and watchOS), the colored variants are alternate icons listed in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` and in `IconNames.all` (with a localized title and glyph color). The picker in Settings ([AppIconPicker.swift](Toolbox/Icons/AppIconPicker.swift)) draws each icon live from its exported background plus the vector tool glyph, so the glyph can react to device tilt; both live in `Assets.xcassets/Icon Previews`, next to `Launch Icon`, the full primary icon as PNG for the launch screen. After adding or editing an icon, run `Toolbox/Icons/export-previews.sh` to regenerate them.

## Localization

All user-facing strings must be wrapped in `NSLocalizedString(_, comment:)`. Translations live in the String Catalog [Localizable.xcstrings](Localizable.xcstrings) (source language English; currently English + German). Menu titles use `comment: "Menu item"`; WhatsNewKit strings use `comment: "WhatsNewKit item"`.

Crowdin is the source of truth for translations: add new strings in English only and translate them, German included, on Crowdin. Its "New Crowdin updates" pull requests (from the `crowdin` branch) rewrite the catalogs and would turn a translation that only exists in the repository back into the English text.

Give every string a comment that says where it appears and what it is (e.g. `comment: "Wake On Lan form: validation error"`): community translators on [Crowdin](https://crowdin.com/project/toolbox) only see the text and its comment. The Crowdin GitHub integration reads both catalogs as configured in [crowdin.yml](crowdin.yml) and opens pull requests with the translations.

## Releasing a new version

When shipping a user-visible feature, update the WhatsNewKit collection in [ToolboxApp.swift](Toolbox/ToolboxApp.swift) (`whatsNewCollection`): bump the `version` string and add a `WhatsNew.Feature` (SF Symbol image + localized title/subtitle). This drives the "What's New" sheet shown on first launch after an update.

The sheet's "Learn more" button opens `https://toolbox.sivery.de/#version<major.minor>`, so add the release notes for the new version to [web/index.html](web/index.html) with that `id` once the version is in the App Store (not before).

## Website

[web/](web/) is the static website at toolbox.sivery.de: plain HTML pages and one hand-written, commented [style.css](web/style.css). No build step, no framework, no JavaScript. Keeping the source easy to read for humans is a deliberate choice; don't add tooling that generates or minifies it. Header and footer are duplicated in every page, so change them in all of them.

- **Formatting:** always run Prettier after editing, with the config in [web/.prettierrc.json](web/.prettierrc.json) (tabs):
  ```bash
  npx prettier@3.9.9 --write "web/**/*.{html,css}"
  ```
- **Hosting:** nginx in Docker ([web/Dockerfile](web/Dockerfile), [web/nginx.conf](web/nginx.conf)). The nginx config holds the `/download` and `/support` redirects the app links to. [.github/workflows/web.yml](.github/workflows/web.yml) rebuilds and pushes `ghcr.io/siveryt/toolbox-web` on every push to `main` that touches `web/`.
- **Main screenshot:** `web/assets/mainscreen.webp` is generated by the fastlane hook [fastlane/hooks/post_frame.d/50-website](fastlane/hooks/post_frame.d/50-website); regenerate it with the screenshot lanes instead of editing it.
- **Legal pages** (`imprint.html`, `privacy.html`, `terms.html`): the privacy policy lists every permission and every network request the app makes (e.g. IP-Checker → `checkip.amazonaws.com`). Update it when a tool adds a permission or talks to a new server.

## Key third-party dependencies (SPM)

`RomanNumeralKit`, `CodeScanner` (barcode/QR), `LanScanner` (fork under `siveryt`), `SwiftyPing` (ping), `swift-async-dns-resolver`, `Swifter` (HTTP server), `MarqueeText` (fork under `siveryt`, scrolling text), `WhatsNewKit`, `Haptica`, `ToastSwiftUI`, `SwiftUI-Apple-Watch-Decimal-Pad`.
