import XCTest

final class SystemTextEntryTests: XCTestCase {
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let hierarchy = XCTAttachment(string: XCUIApplication().debugDescription)
        hierarchy.name = name + "-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    func testTypedSystemCompletionAndReturn() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--simulator-text-entry"]
        app.launch()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 15))
        capture("01-real-system-keyboard")
        app.typeText("watch test")
        capture("02-typed-not-speech")
        done.tap()
        XCTAssertTrue(app.staticTexts["听写结果"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["watch test"].exists)
        capture("03-real-completion-preview")
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["dictation-button"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["听写结果"].exists)
        capture("04-return-after-done")
    }

    func testSystemCancelReturnsWithoutPreview() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--simulator-text-entry"]
        app.launch()
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 15))
        cancel.tap()
        XCTAssertTrue(app.buttons["dictation-button"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["听写结果"].exists)
        capture("05-return-after-cancel")
    }
}
