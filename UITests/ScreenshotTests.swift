import XCTest

/// Captures the four screens used in the report.
///
/// Skipped by default: it writes files to /tmp, which only makes sense when
/// explicitly asked for. Run with:
/// `touch /tmp/capture-screenshots && xcodebuild test -only-testing:CamCardReplicaUITests/ScreenshotTests`
final class ScreenshotTests: XCTestCase {
    private let outputDirectory = URL(fileURLWithPath: "/tmp/camcard-shots")

    /// Marker file gate: `touch /tmp/capture-screenshots` before running.
    /// Build-settings based gating (TEST_RUNNER_*) is unreliable across Xcode
    /// versions, and a file is trivial to script.
    private static let marker = "/tmp/capture-screenshots"

    override func setUpWithError() throws {
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: Self.marker),
            "touch \(Self.marker) to capture screenshots"
        )
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    private func save(_ name: String) {
        // Give the transition a moment: a screenshot taken during the push/cover
        // animation captures a half-composed frame.
        Thread.sleep(forTimeInterval: 1.2)
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }

    func testCaptureMainScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "YES", "-seed-data", "NO", "-fixture-camera", "YES"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["empty-state"].waitForExistence(timeout: 10))
        save("01-empty")

        app.terminate()
        app.launchArguments = ["-ui-testing", "YES", "-seed-data", "YES", "-fixture-camera", "YES"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["card-list"].waitForExistence(timeout: 10))
        save("02-list")

        app.buttons["scan-button"].tap()
        app.buttons["fixture-capture"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["preview-view"].waitForExistence(timeout: 10))
        save("03-preview")

        app.buttons["preview-use"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["crop-view"].waitForExistence(timeout: 10))
        save("04-crop")

        app.buttons["crop-confirm"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["review-view"].waitForExistence(timeout: 30))
        save("05-review")

        app.buttons["review-save"].tap()
        XCTAssertTrue(app.staticTexts["朱宏明"].waitForExistence(timeout: 10))
        app.staticTexts["朱宏明"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail-view"].waitForExistence(timeout: 10))
        save("06-detail")
    }
}
