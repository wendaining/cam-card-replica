import XCTest

/// Opt-in AVFoundation capture check using the separately installed FauxCam tool.
final class FauxCameraUITests: XCTestCase {
    func testT04_fauxCameraShutterRetakeRecognizeAndSave() throws {
        continueAfterFailure = false
        let configURL = URL(fileURLWithPath: "/tmp/camcard-fauxcam-config.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: configURL.path), "FauxCam configuration required")
        let config = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: configURL))
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "YES", "-seed-data", "NO", "-fixture-camera", "NO"]
        app.launchEnvironment = try [
            "DYLD_INSERT_LIBRARIES": XCTUnwrap(config["dylib"]),
            "FAUXCAM_SOCKET": XCTUnwrap(config["socket"]),
            "FAUXCAM_WIDTH": "720", "FAUXCAM_HEIGHT": "1280", "FAUXCAM_FPS": "15",
        ]
        app.launch()
        defer { app.terminate() }
        app.buttons["scan-button"].tap()
        let shutter = app.buttons["shutter-button"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        XCTAssertTrue(shutter.isEnabled)
        XCTAssertFalse(app.buttons["fixture-capture"].exists)
        capture("01-camera")
        shutter.tap()
        XCTAssertTrue(element("preview-view", in: app).waitForExistence(timeout: 15))
        capture("02-preview")
        app.buttons["preview-retake"].tap()
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        shutter.tap()
        XCTAssertTrue(element("preview-view", in: app).waitForExistence(timeout: 15))
        app.buttons["preview-use"].tap()
        XCTAssertTrue(element("crop-view", in: app).waitForExistence(timeout: 15))
        capture("03-crop")
        app.buttons["crop-confirm"].tap()
        XCTAssertTrue(element("review-view", in: app).waitForExistence(timeout: 30))
        XCTAssertEqual(app.textFields["field-name"].value as? String, "David Chen")
        capture("04-review")
        app.buttons["raw-text-button"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "David Chen")).firstMatch
            .exists)
        capture("05-raw-text")
        app.buttons["完成"].tap()
        app.buttons["review-save"].tap()
        XCTAssertTrue(app.staticTexts["David Chen"].waitForExistence(timeout: 10))
        capture("06-saved")
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "faux-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        let directory = URL(fileURLWithPath: "/tmp/camcard-fauxcam-shots")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
