//
//  ScreenshotTests.swift
//  ToolboxUITests
//
//  Drives the app for `fastlane screenshots`. Not a functional test suite.
//

import XCTest

final class ScreenshotTests: XCTestCase {

    /// Screens to capture, in App Store order. `tool` is the SF Symbol the tool is registered with in `toollist`
    /// (exposed as accessibility identifier "tool.<icon>"); nil captures the main menu, "menu.end" the menu scrolled to its end.
    /// The name must match the filters in fastlane/screenshots/Framefile.json and the keys in title.strings.
    private let screens: [(name: String, tool: String?)] = [
        ("01Menu", nil),
        ("02Dice", "dice"),
        ("03QRCode", "qrcode"),
        ("04Roman", "hexagon"),
        ("05DateDifference", "calendar"),
        ("06Metronome", "metronome"),
        ("07More", "menu.end"),
    ]

    @MainActor
    func testScreenshots() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        setupSnapshot(app)
        // Launch arguments win over stored defaults: default order, nothing hidden,
        // and a launch count that never reaches the tip / review-prompt thresholds.
        app.launchArguments += ["-cvLoaded", "0", "-cvOrder", "[0]", "-cvHidden", "[]"]
        app.launch()

        for screen in screens {
            if screen.tool == "menu.end" {
                for _ in 0..<4 { app.swipeUp() }
                snapshot(screen.name, timeWaitingForIdle: 0)
            } else if let tool = screen.tool {
                open(tool: tool, in: app)
                snapshot(screen.name, timeWaitingForIdle: 0)
                app.navigationBars.buttons.element(boundBy: 0).tap()
            } else {
                snapshot(screen.name, timeWaitingForIdle: 0)
            }
        }
    }

    /// Taps a menu row, scrolling the lazy list down and then back up until the row exists.
    @MainActor
    private func open(tool icon: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any).matching(identifier: "tool." + icon).firstMatch
        for swipe in 0..<16 {
            if row.waitForExistence(timeout: 1) && row.isHittable { break }
            if swipe < 8 { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(row.exists, "Menu row tool.\(icon) not found")
        row.tap()
    }
}
