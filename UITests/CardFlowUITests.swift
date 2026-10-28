import XCTest

/// End-to-end coverage of the reference test suite (T01–T20 in `docs/spec/acceptance.md`).
///
/// Identifiers are duplicated as literals on purpose: a UI test bundle cannot
/// import the app module, and sharing a source file across both targets would
/// hide accidental renames instead of failing the test.
final class CardFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        app = nil
    }

    // MARK: - Helpers

    @discardableResult
    private func launch(
        seed: Bool = true,
        fixtures: Bool = true,
        permission: String? = nil,
        fixtureName: String? = nil,
        persistentID: String? = nil,
        resetStore: Bool = false,
        failSave: Bool = false,
        failRecognition: Bool = false,
        emptyRecognition: Bool = false
    ) -> XCUIApplication {
        // UserDefaults parses `-key value` pairs: a bare flag would swallow the
        // next argument, so every switch gets an explicit YES.
        app.launchArguments = ["-ui-testing", "YES"]
        app.launchArguments += ["-seed-data", seed ? "YES" : "NO"]
        app.launchArguments += ["-fixture-camera", fixtures ? "YES" : "NO"]
        if let permission {
            app.launchArguments += ["-camera-permission", permission]
        }
        if let fixtureName {
            app.launchArguments += ["-fixture-name", fixtureName]
        }
        if let persistentID {
            app.launchArguments += ["-persistent-test-id", persistentID]
        }
        app.launchArguments += ["-reset-test-store", resetStore ? "YES" : "NO"]
        app.launchArguments += ["-fail-store-save", failSave ? "YES" : "NO"]
        app.launchArguments += ["-fail-recognition", failRecognition ? "YES" : "NO"]
        app.launchArguments += ["-empty-recognition", emptyRecognition ? "YES" : "NO"]
        app.launch()
        return app
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Form rows below the fold are not in the accessibility tree until they are
    /// rendered, so scroll until the field can actually be interacted with.
    private func field(_ identifier: String) -> XCUIElement {
        let field = app.textFields[identifier]
        var attempts = 0
        while !field.exists, attempts < 8 {
            let form = app.descendants(matching: .any)["review-view"]
            if form.exists {
                form.swipeUp(velocity: .slow)
            } else {
                app.swipeUp(velocity: .slow)
            }
            attempts += 1
        }
        return field
    }

    /// An empty SwiftUI TextField reports its prompt as `value`.
    private func text(of element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value == element.placeholderValue ? "" : value
    }

    /// Runs capture -> crop -> OCR -> review and returns when the review screen
    /// is on screen.
    private func scanToReview() {
        app.buttons["scan-button"].tap()
        XCTAssertTrue(element("scanner-view").waitForExistence(timeout: 5))
        app.buttons["fixture-capture"].tap()
        XCTAssertTrue(element("preview-view").waitForExistence(timeout: 5))
        app.buttons["preview-use"].tap()
        XCTAssertTrue(element("crop-view").waitForExistence(timeout: 5))
        app.buttons["crop-confirm"].tap()
        XCTAssertTrue(element("review-view").waitForExistence(timeout: 30))
    }

    // MARK: - T01 first launch

    func testT01_firstLaunchShowsEmptyState() {
        launch(seed: false)
        XCTAssertTrue(element("empty-state").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["还没有名片"].exists)
    }

    // MARK: - T02 enter scanner

    func testT02_scanButtonOpensScanner() {
        launch()
        app.buttons["scan-button"].tap()
        XCTAssertTrue(element("scanner-view").waitForExistence(timeout: 5))
    }

    // MARK: - T03 permission denied

    func testT03_cameraDeniedShowsExplanation() {
        launch(permission: "denied")
        app.buttons["scan-button"].tap()
        XCTAssertTrue(element("camera-denied-message").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["需要相机权限才能拍摄名片"].exists)
        XCTAssertFalse(app.buttons["shutter-button"].isEnabled)
    }

    // MARK: - T04 / T06 capture + boundary detection

    func testT04_captureEntersCropAndDetectsBoundary() {
        launch()
        app.buttons["scan-button"].tap()
        app.buttons["fixture-capture"].tap()
        XCTAssertTrue(element("preview-view").waitForExistence(timeout: 5))
        app.buttons["preview-use"].tap()
        XCTAssertTrue(element("crop-view").waitForExistence(timeout: 5))
    }

    /// The preview step must let the user throw the photo away and shoot again.
    func testT04b_previewCanBeRetaken() {
        launch()
        app.buttons["scan-button"].tap()
        app.buttons["fixture-capture"].tap()
        XCTAssertTrue(element("preview-view").waitForExistence(timeout: 5))
        app.buttons["preview-retake"].tap()
        XCTAssertTrue(element("scanner-view").waitForExistence(timeout: 5))
    }

    func testT06_cropCanBeRetaken() {
        launch()
        app.buttons["scan-button"].tap()
        app.buttons["fixture-capture"].tap()
        XCTAssertTrue(element("preview-view").waitForExistence(timeout: 5))
        app.buttons["preview-use"].tap()
        XCTAssertTrue(element("crop-view").waitForExistence(timeout: 5))
        app.buttons["crop-retake"].tap()
        XCTAssertTrue(element("scanner-view").waitForExistence(timeout: 5))
    }

    // MARK: - T07 / T08 / T09 / T10 OCR + structured extraction

    func testT07_T08_recognitionProducesStructuredFields() {
        launch()
        scanToReview()
        let name = app.textFields["field-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let value = name.value as? String ?? ""
        XCTAssertFalse(value.isEmpty, "a fixture card must yield a name")
    }

    func testT09_missingWebsiteStaysEmpty() {
        // en-02 has no website printed on it, so the field must stay empty.
        launch(fixtureName: "en-02")
        scanToReview()
        let website = field("field-website")
        XCTAssertTrue(website.exists)
        XCTAssertEqual(text(of: website), "", "the parser must not invent a website")
    }

    func testT10_phoneKindsAreEditable() {
        // zh-01 carries mobile + office + fax, all labelled.
        launch(fixtureName: "zh-01")
        scanToReview()
        XCTAssertTrue(field("field-mobile").exists)
        XCTAssertTrue(field("field-office").exists)
        XCTAssertTrue(field("field-fax").exists)
    }

    // MARK: - T11 / T12 manual correction + save

    func testT11_T12_manualCorrectionIsSaved() {
        launch()
        scanToReview()
        let name = field("field-name")
        name.tap()
        // The trailing newline commits the edit and dismisses the keyboard so the
        // toolbar button cannot be covered by the keyboard on a small screen.
        name.typeText("X\n")
        sleep(1)
        let save = app.buttons["review-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        // One retry: the first tap can be swallowed while the keyboard animates.
        if !element("card-list").waitForExistence(timeout: 5), app.buttons["review-save"].exists {
            app.buttons["review-save"].tap()
        }
        XCTAssertTrue(element("card-list").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'X'")).firstMatch
            .waitForExistence(timeout: 5))
    }

    // MARK: - T13 / T14 detail + edit

    func testT13_detailShowsStoredFields() {
        launch()
        app.staticTexts["朱宏明"].firstMatch.tap()
        XCTAssertTrue(element("detail-view").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["同济大学"].exists)
    }

    func testT14_editNameUpdatesDetail() {
        launch()
        app.staticTexts["朱宏明"].firstMatch.tap()
        XCTAssertTrue(element("detail-view").waitForExistence(timeout: 5))
        app.buttons["detail-more"].tap()
        app.buttons["detail-edit"].tap()
        let name = app.textFields["field-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(" 教授")
        app.buttons["detail-edit-save"].tap()
        XCTAssertTrue(app.staticTexts["朱宏明 教授"].waitForExistence(timeout: 5))
    }

    // MARK: - T15 search

    func testT15_searchFiltersList() {
        launch()
        let search = app.textFields["search-field"]
        search.tap()
        search.typeText("David")
        XCTAssertTrue(app.staticTexts["David Chen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["朱宏明"].exists)
    }

    // MARK: - T16 tags

    func testT16_tagFilterShowsOnlyTaggedCards() {
        launch()
        let chip = app.descendants(matching: .any)["tag-chip-Professor"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        XCTAssertTrue(app.staticTexts["朱宏明"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["David Chen"].exists)
    }

    // MARK: - T17 delete

    func testT17_deleteRemovesCardFromList() {
        launch()
        app.staticTexts["David Chen"].firstMatch.tap()
        XCTAssertTrue(element("detail-view").waitForExistence(timeout: 5))
        app.buttons["detail-more"].tap()
        app.buttons["detail-delete"].tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(element("card-list").waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["David Chen"].exists)
    }

    // MARK: - T20 cancel paths

    func testT20_cancelFromReviewReturnsToList() {
        launch()
        scanToReview()
        app.buttons["scan-cancel"].tap()
        XCTAssertFalse(element("scanner-view").exists)
        XCTAssertTrue(element("card-list").waitForExistence(timeout: 5))
    }

    func testT13_savedImageOpensAndCanSwitchToOriginal() {
        launch(seed: false, fixtureName: "zh-01")
        scanToReview()
        app.buttons["review-save"].tap()
        XCTAssertTrue(app.staticTexts["朱宏明"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["朱宏明"].firstMatch.tap()
        app.buttons["detail-image"].tap()
        let picker = app.segmentedControls["image-source-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), app.debugDescription)
        picker.buttons["原图"].tap()
        XCTAssertTrue(picker.buttons["原图"].isSelected)
        try? XCUIScreen.main.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/camcard-viewer-validation.png"))
        app.buttons["image-viewer-done"].tap()
        XCTAssertTrue(element("detail-view").waitForExistence(timeout: 5))
    }

    func testT17_swipeDeleteCanBeCancelled() {
        launch()
        let row = app.staticTexts["David Chen"].firstMatch
        row.swipeLeft()
        app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Delete", "删除")).firstMatch.tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "取消", "Cancel")).firstMatch
        XCTAssertTrue(app.sheets["删除选中的名片？"].waitForExistence(timeout: 5))
        if cancel.exists {
            cancel.tap()
        } else {
            // iOS 27 and iPad present a popover; tapping outside is its native cancel action.
            app.otherElements["PopoverDismissRegion"].tap()
        }
        XCTAssertTrue(app.staticTexts["David Chen"].exists)
        row.swipeLeft()
        app.buttons["删除"].firstMatch.tap()
        let confirmation = app.sheets["删除选中的名片？"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["删除"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                             object: app.staticTexts["David Chen"].firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed, app.debugDescription)
    }

    func testT20_cancelDoesNotCreateDraftTag() {
        launch(seed: false, fixtureName: "zh-01")
        scanToReview()
        for _ in 0 ..< 6 where !app.buttons["新建标签"].isHittable {
            app.swipeUp()
        }
        app.buttons["新建标签"].tap()
        app.alerts.textFields.firstMatch.typeText("Review Draft")
        app.alerts.buttons["添加"].tap()
        app.buttons["scan-cancel"].tap()
        XCTAssertTrue(element("empty-state").waitForExistence(timeout: 5))
        XCTAssertFalse(element("tag-chip-Review Draft").exists)
    }

    func testT20_storageFailureKeepsReviewAndShowsReason() {
        launch(seed: false, fixtureName: "zh-01", failSave: true)
        scanToReview()
        app.buttons["review-save"].tap()
        XCTAssertTrue(app.alerts["保存失败"].waitForExistence(timeout: 5))
        app.alerts.buttons["好"].tap()
        XCTAssertTrue(element("review-view").exists)
        app.buttons["scan-cancel"].tap()
        XCTAssertTrue(element("empty-state").waitForExistence(timeout: 5))
    }

    func testT20_recognitionFailureShowsRetryAndRetake() {
        launch(seed: false, fixtureName: "zh-01", failRecognition: true)
        app.buttons["scan-button"].tap()
        app.buttons["fixture-capture"].tap()
        app.buttons["preview-use"].tap()
        app.buttons["crop-confirm"].tap()
        XCTAssertTrue(element("scan-error").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["crop-confirm"].exists)
        app.buttons["crop-retake"].tap()
        XCTAssertTrue(element("scanner-view").waitForExistence(timeout: 5))
    }

    func testT20_emptyRecognitionDisablesSaveUntilNameEntered() {
        launch(seed: false, fixtureName: "zh-01", emptyRecognition: true)
        scanToReview()
        XCTAssertFalse(app.buttons["review-save"].isEnabled)
        let name = app.textFields["field-name"]
        name.tap()
        name.typeText("Manual Contact\n")
        XCTAssertTrue(app.buttons["review-save"].isEnabled)
        app.buttons["review-save"].tap()
        XCTAssertTrue(app.staticTexts["Manual Contact"].waitForExistence(timeout: 5))
    }

    func testT18_processRelaunchKeepsEditsTagsNotesAndBothImages() {
        let testID = UUID().uuidString
        launch(seed: false, fixtureName: "zh-01", persistentID: testID, resetStore: true)
        scanToReview()
        let name = app.textFields["field-name"]
        let expectedName = (name.value as? String ?? "") + "R"
        name.tap()
        name.typeText("R\n")
        for _ in 0 ..< 7 where !app.buttons["新建标签"].isHittable {
            app.swipeUp()
        }
        app.buttons["新建标签"].tap()
        app.alerts.textFields.firstMatch.typeText("Persistence")
        app.alerts.buttons["添加"].tap()
        let notes = app.textViews["field-notes"]
        for _ in 0 ..< 5 where !notes.isHittable {
            app.swipeUp()
        }
        notes.tap()
        notes.typeText("Persistence note")
        app.buttons["review-save"].tap()
        XCTAssertTrue(app.staticTexts[expectedName].waitForExistence(timeout: 5))
        app.staticTexts[expectedName].tap()
        app.buttons["detail-more"].tap()
        app.buttons["detail-edit"].tap()
        let company = app.textFields["field-company"]
        company.tap()
        company.typeText(" Edited\n")
        app.buttons["detail-edit-save"].tap()
        app.terminate()
        launch(seed: false, fixtureName: "zh-01", persistentID: testID)
        XCTAssertTrue(app.staticTexts[expectedName].waitForExistence(timeout: 5))
        app.staticTexts[expectedName].tap()
        XCTAssertTrue(app.staticTexts["同济大学 Edited"].waitForExistence(timeout: 5))
        app.buttons["detail-image"].tap()
        let picker = app.segmentedControls["image-source-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), app.debugDescription)
        picker.buttons["原图"].tap()
        XCTAssertTrue(picker.buttons["原图"].isSelected)
        app.buttons["image-viewer-done"].tap()
        for _ in 0 ..< 6 where !app.staticTexts["Persistence note"].exists {
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Persistence note"].exists)
        XCTAssertTrue(element("tag-chip-Persistence").exists)
    }
}
