@testable import CamCardReplica
import CoreGraphics
import ImageIO
import XCTest

private final class ControlledRecognizer: TextRecognizing, @unchecked Sendable {
    let entered: XCTestExpectation
    let release = DispatchSemaphore(value: 0)

    init(entered: XCTestExpectation) {
        self.entered = entered
    }

    func recognize(image: CGImage, orientation: CGImagePropertyOrientation) throws -> OCRResult {
        entered.fulfill()
        _ = release.wait(timeout: .now() + 3)
        return .empty
    }
}

private struct ThrowingRecognizer: TextRecognizing {
    func recognize(image: CGImage, orientation: CGImagePropertyOrientation) throws -> OCRResult {
        throw CocoaError(.fileReadCorruptFile)
    }
}

@MainActor
final class ScanFlowModelTests: XCTestCase {
    func testRecognitionRunsOffMainActorAndLateResultIsDiscarded() async {
        let entered = expectation(description: "recognizer entered")
        let recognizer = ControlledRecognizer(entered: entered)
        let services = TestServices.make(store: InMemoryCardStore(), recognizer: recognizer)
        let model = ScanFlowModel(services: services)
        model.handle(image: TestServices.image())
        await model.confirmPreview()
        let work = Task { await model.confirmCrop() }
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertEqual(model.stage, .processing, "the main actor must respond while OCR is blocked")
        model.retake()
        recognizer.release.signal()
        await work.value
        XCTAssertEqual(model.stage, .capture)
        XCTAssertNil(model.ocr)
        XCTAssertNil(model.capturedImage)
        XCTAssertTrue(services.library.cards.isEmpty)
    }

    func testRecognitionErrorReturnsToCropForRetry() async {
        let model = ScanFlowModel(services: TestServices.make(
            store: InMemoryCardStore(),
            recognizer: ThrowingRecognizer()
        ))
        model.handle(image: TestServices.image())
        await model.confirmPreview()
        await model.confirmCrop()
        XCTAssertEqual(model.stage, .crop)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNotNil(model.capturedImage)
    }

    func testEmptyOCRAllowsManualEntryWithoutInventingFields() async {
        let store = InMemoryCardStore()
        let model = ScanFlowModel(services: TestServices.make(store: store))
        model.handle(image: TestServices.image())
        await model.confirmPreview()
        await model.confirmCrop()
        XCTAssertEqual(model.stage, .review)
        XCTAssertFalse(model.draft.canSave)
        model.draft.name = "Manual Entry"
        XCTAssertNotNil(model.save())
        XCTAssertEqual(store.library.cards.first?.name, "Manual Entry")
    }

    func testFailedSaveReturnsNilAndKeepsDraftForRetry() {
        let store = FailingCardStore()
        store.failsSave = true
        let services = TestServices.make(store: store)
        let model = ScanFlowModel(services: services)
        model.handle(image: TestServices.image())
        model.draft.name = "Review Contact"
        XCTAssertNil(model.save())
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.draft.name, "Review Contact")
        XCTAssertTrue(services.library.cards.isEmpty)
        XCTAssertTrue(store.images.isEmpty)
        store.failsSave = false
        XCTAssertNotNil(model.save())
        XCTAssertEqual(store.library.cards.count, 1)
    }

    func testBlankNameDoesNotWriteImagesOrRecord() {
        let store = FailingCardStore()
        let model = ScanFlowModel(services: TestServices.make(store: store))
        model.handle(image: TestServices.image())
        XCTAssertNil(model.save())
        XCTAssertTrue(store.images.isEmpty)
        XCTAssertTrue(store.library.cards.isEmpty)
    }
}
