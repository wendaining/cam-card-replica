import XCTest

/// Explicitly enabled checks against the simulator's system camera authorization.
final class SystemCameraPermissionUITests: XCTestCase {
    func testT03_systemCameraPermission() throws {
        continueAfterFailure = false
        let configURL = URL(fileURLWithPath: "/tmp/camcard-system-camera-config.json")
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: configURL.path),
            "System camera test configuration required"
        )
        let config = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: configURL))
        let expected = try XCTUnwrap(config["expected"])
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "YES", "-seed-data", "NO", "-fixture-camera", "NO"]
        app.launch()
        defer { app.terminate() }
        app.buttons["scan-button"].tap()
        if expected.hasPrefix("prompt-") {
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let alert = springboard.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 10), "No system camera permission alert appeared")
            print("SYSTEM_CAMERA_ALERT=" + alert.label)
            print("SYSTEM_CAMERA_ALERT_BUTTONS=" + alert.buttons.allElementsBoundByIndex.map(\.label)
                .joined(separator: "|"))
            capture("prompt-" + expected)
            let titles = expected == "prompt-allow" ? ["Allow", "OK", "允许", "好"] : ["Don’t Allow", "Don't Allow", "不允许"]
            let button = try XCTUnwrap(titles.map { alert.buttons[$0] }.first(where: \.exists))
            button.tap()
        }
        let shutter = app.buttons["shutter-button"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        let allowed = expected == "authorized" || expected == "prompt-allow"
        let enabled = NSPredicate(format: "enabled == %@", NSNumber(value: allowed))
        expectation(for: enabled, evaluatedWith: shutter)
        waitForExpectations(timeout: 10)
        let explanation = app.descendants(matching: .any)["camera-denied-message"]
        XCTAssertEqual(explanation.exists, !allowed)
        XCTAssertFalse(app.buttons["fixture-capture"].exists)
        capture(expected)
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "system-camera-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/camcard-system-camera-shots")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
