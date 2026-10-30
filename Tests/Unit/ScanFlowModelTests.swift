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
private final class ControlledImageLoader {
    let entered: XCTestExpectation
    private var continuation: CheckedContinuation<Data?, Error>?

    init(entered: XCTestExpectation) {
        self.entered = entered
    }

    func load() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            entered.fulfill()
        }
    }

    func finish(_ result: Result<Data?, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

@MainActor
final class ScanFlowModelTests: XCTestCase {
    func testImageImportShowsCropAndReportsCurrentLoadErrors() async throws {
        let data = try XCTUnwrap(ImageCoding.jpegData(from: TestServices.image()))
        let model = ScanFlowModel(services: TestServices.make(store: InMemoryCardStore()))
        await model.importImage { data }
        XCTAssertEqual(model.stage, .crop)
        XCTAssertNotNil(model.capturedImage)
        XCTAssertNil(model.errorMessage)
        let failures: [Result<Data?, Error>] = [
            .success(nil), .success(Data([0])), .failure(CocoaError(.fileReadCorruptFile)),
        ]
        for result in failures {
            model.retake()
            await model.importImage { try result.get() }
            XCTAssertEqual(model.stage, .capture)
            XCTAssertNil(model.capturedImage)
            XCTAssertNotNil(model.errorMessage)
        }
    }

    func testLateImageImportCannotReplaceReviewedCaptureOrReportOldError() async throws {
        let data = try XCTUnwrap(ImageCoding.jpegData(from: TestServices.image()))
        for fails in [false, true] {
            let store = InMemoryCardStore()
            let model = ScanFlowModel(services: TestServices.make(store: store))
            let entered = expectation(description: "image loading")
            let loader = ControlledImageLoader(entered: entered)
            let work = Task { await model.importImage { try await loader.load() } }
            await fulfillment(of: [entered], timeout: 2)
            let replacement = TestServices.image()
            model.handle(image: replacement)
            await model.confirmPreview()
            await model.confirmCrop()
            model.draft.name = "Edited new capture"
            loader.finish(fails ? .failure(CocoaError(.fileReadCorruptFile)) : .success(data))
            await work.value
            XCTAssertEqual(model.stage, .review)
            XCTAssertTrue(model.capturedImage === replacement)
            XCTAssertEqual(model.draft.name, "Edited new capture")
            XCTAssertNil(model.errorMessage)
            XCTAssertTrue(store.library.cards.isEmpty)
        }
    }

    func testNewImageSelectionSupersedesPendingImport() async throws {
        let data = try XCTUnwrap(ImageCoding.jpegData(from: TestServices.image()))
        let model = ScanFlowModel(services: TestServices.make(store: InMemoryCardStore()))
        let entered = expectation(description: "old selection loading")
        let loader = ControlledImageLoader(entered: entered)
        let old = Task { await model.importImage { try await loader.load() } }
        await fulfillment(of: [entered], timeout: 2)
        await model.importImage { data }
        let selected = try XCTUnwrap(model.capturedImage)
        loader.finish(.success(data))
        await old.value
        XCTAssertEqual(model.stage, .crop)
        XCTAssertTrue(model.capturedImage === selected)
        XCTAssertNil(model.errorMessage)
    }

    func testCancelledImageImportDoesNotReviveCapture() async throws {
        let data = try XCTUnwrap(ImageCoding.jpegData(from: TestServices.image()))
        for cancelTask in [false, true] {
            let store = InMemoryCardStore()
            let model = ScanFlowModel(services: TestServices.make(store: store))
            let entered = expectation(description: "cancelled image loading")
            let loader = ControlledImageLoader(entered: entered)
            let work = Task { await model.importImage { try await loader.load() } }
            await fulfillment(of: [entered], timeout: 2)
            if cancelTask {
                work.cancel()
            } else {
                model.retake()
            }
            loader.finish(.success(data))
            await work.value
            XCTAssertEqual(model.stage, .capture)
            XCTAssertNil(model.capturedImage)
            XCTAssertNil(model.errorMessage)
            XCTAssertTrue(store.library.cards.isEmpty)
        }
        let model = ScanFlowModel(services: TestServices.make(store: InMemoryCardStore()))
        let current = TestServices.image()
        model.handle(image: current)
        let cancelled = Task { await model.importImage { data } }
        cancelled.cancel()
        await cancelled.value
        XCTAssertEqual(model.stage, .preview)
        XCTAssertTrue(model.capturedImage === current, "an already cancelled task must not reset the current capture")
    }

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
