//
//  WatchScreenshotTests.swift
//  ToolboxWatchUITests
//
//  Drives the watch app for `fastlane screenshots_watch`. Not a functional test suite.
//

import XCTest

final class WatchScreenshotTests: XCTestCase {

    /// `tool` is the accessibility identifier suffix set in the watch ContentView; nil captures the menu.
    private let screens: [(name: String, tool: String?)] = [
        ("01Menu", nil),
        ("02Dice", "dice"),
        ("03Counter", "plusminus"),
        ("04RandomNumber", "number"),
    ]

    @MainActor
    func testScreenshots() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        for screen in screens {
            if let tool = screen.tool {
                let row = app.descendants(matching: .any).matching(identifier: "tool." + tool).firstMatch
                XCTAssertTrue(row.waitForExistence(timeout: 10), "Menu row tool.\(tool) not found")
                row.tap()
                snapshot(screen.name, timeWaitingForIdle: 0)
                app.navigationBars.buttons.element(boundBy: 0).tap()
            } else {
                snapshot(screen.name, timeWaitingForIdle: 0)
            }
        }
    }
}
