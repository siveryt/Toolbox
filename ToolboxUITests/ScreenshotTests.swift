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
        ("07Camera", "camera.viewfinder"),
        ("08More", "menu.end"),
    ]

    @MainActor
    func testScreenshots() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        setupSnapshot(app)
        // Launch arguments win over stored defaults: default order, nothing hidden,
        // a launch count that never reaches the tip / review-prompt thresholds,
        // and a single unlocked six-sided die whatever the simulator was last left at.
        app.launchArguments += ["-cvLoaded", "0", "-cvOrder", "[0]", "-cvHidden", "[]"]
        app.launchArguments += ["-diceCount", "1", "-diceSides", "6", "-diceKept", "[]"]
        app.launch()

        for screen in screens {
            if screen.tool == "menu.end" {
                for _ in 0..<4 { app.swipeUp() }
                snapshot(screen.name, timeWaitingForIdle: 0)
            } else if let tool = screen.tool {
                open(tool: tool, in: app)
                snapshot(screen.name, timeWaitingForIdle: 0)
                goBack(in: app)
            } else {
                snapshot(screen.name, timeWaitingForIdle: 0)
            }
        }
    }

    /// Returns to the menu. The iPhone Duo's outer display shows the navigation controls in a bar
    /// at the side instead of a navigation bar, so the back button is also looked up by its identifier.
    @MainActor
    private func goBack(in app: XCUIApplication) {
        let navigationBarButton = app.navigationBars.buttons.element(boundBy: 0)
        if navigationBarButton.waitForExistence(timeout: 2) {
            navigationBarButton.tap()
            return
        }
        let backButton = app.buttons.matching(identifier: "BackButton").firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 2), "Back button not found")
        backButton.tap()
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
