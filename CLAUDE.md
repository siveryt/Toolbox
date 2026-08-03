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
- There is a UI test target directory (`ToolboxUITests/`) but it is effectively empty — there is no meaningful automated test suite. Verify changes by running the app.
- `Buildnumber.xcconfig` (holds `BUILD_NUMBER` / `LAST_UPDATE`) and the `AppStore/` directory are git-ignored; `CURRENT_PROJECT_VERSION` reads `$(BUILD_NUMBER)` from that file, so a clean checkout may need it present to build the Release config.

### Driving the app in the iOS Simulator

The simulator control tool's `tap`/`swipe` coordinates are in **device points** (e.g. 402×874 for an iPhone 17 Pro), **not** screenshot pixels. Screenshots come back at the device scale factor (≈2.27× on that device, so ≈913 px wide). Read a position off a screenshot in pixels and you must divide by the scale factor before tapping — e.g. a row at screenshot pixel `(276, 1578)` is point `(≈121, ≈695)`. Feeding raw pixel values makes taps land far below the intended target (and silently hit the wrong row).

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

## Localization

All user-facing strings must be wrapped in `NSLocalizedString(_, comment:)`. Translations live in the String Catalog [Localizable.xcstrings](Localizable.xcstrings) (source language English; currently English + German). Menu titles use `comment: "Menu item"`; WhatsNewKit strings use `comment: "WhatsNewKit item"`. Adding a new string means adding it to the catalog for existing languages.

## Releasing a new version

When shipping a user-visible feature, update the WhatsNewKit collection in [ToolboxApp.swift](Toolbox/ToolboxApp.swift) (`whatsNewCollection`): bump the `version` string and add a `WhatsNew.Feature` (SF Symbol image + localized title/subtitle). This drives the "What's New" sheet shown on first launch after an update.

## Key third-party dependencies (SPM)

`RomanNumeralKit`, `CodeScanner` (barcode/QR), `LanScanner` (fork under `siveryt`), `SwiftyPing` (ping), `Awake` (Wake-on-LAN), `swift-async-dns-resolver`, `Swifter` (HTTP server), `MarqueeText` (fork under `siveryt`, scrolling text), `WhatsNewKit`, `Haptica`, `ToastSwiftUI`, `SwiftUI-Apple-Watch-Decimal-Pad`.
