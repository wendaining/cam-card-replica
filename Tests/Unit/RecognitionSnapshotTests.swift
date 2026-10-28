@testable import CamCardReplica
import CoreGraphics
import ImageIO
import XCTest

private struct RecordedRecognizer: TextRecognizing {
    let result: OCRResult
    func recognize(image: CGImage, orientation: CGImagePropertyOrientation) throws -> OCRResult {
        result
    }
}

@MainActor
final class RecognitionSnapshotTests: XCTestCase {
    func testOriginalOCRAndParsedFieldsSurviveCorrectionEditAndReload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let ocr = OCRResult(
            lines: [
                OCRTextLine(
                    text: "David Chen",
                    boundingBox: CGRect(x: 0, y: 0, width: 1, height: 0.1),
                    confidence: 0.7
                ),
                OCRTextLine(
                    text: "ABC University",
                    boundingBox: CGRect(x: 0, y: 0.2, width: 1, height: 0.05),
                    confidence: 0.9
                ),
            ],
            rawText: "David Chen\nABC University", imageSize: CGSize(width: 100, height: 60), duration: 0.1,
            languages: ["en-US"]
        )
        let services = TestServices.make(store: FileCardStore(root: root), recognizer: RecordedRecognizer(result: ocr))
        let model = ScanFlowModel(services: services)
        model.handle(image: TestServices.image())
        await model.confirmPreview()
        await model.confirmCrop()
        model.draft.name = "Corrected Name"
        let saved = try XCTUnwrap(model.save())
        var draft = CardDraft(card: saved)
        draft.company = "Edited Company"
        try services.library.update(draft.makeCard(id: saved.id))
        let restored = try XCTUnwrap(CardLibraryModel(store: FileCardStore(root: root)).card(id: saved.id))
        let json = try XCTUnwrap(JSONSerialization
            .jsonObject(with: FileCardStore.encoder.encode(restored)) as? [String: Any])
        let snapshot = try XCTUnwrap(json["recognition"] as? [String: Any])
        let initial = try XCTUnwrap(snapshot["parsed"] as? [String: Any])
        XCTAssertEqual((initial["name"] as? [String: Any])?["value"] as? String, "David Chen")
        let storedOCR = try XCTUnwrap(snapshot["ocr"] as? [String: Any])
        XCTAssertEqual(storedOCR["rawText"] as? String, ocr.rawText)
        XCTAssertEqual((storedOCR["lines"] as? [[String: Any]])?.count, 2)
        XCTAssertEqual(restored.name, "Corrected Name")
        XCTAssertEqual(restored.company, "Edited Company")
    }

    func testLegacyJSONWithoutRecognitionStillDecodes() throws {
        let card = BusinessCard(name: "Legacy")
        var json = try XCTUnwrap(JSONSerialization
            .jsonObject(with: FileCardStore.encoder.encode(card)) as? [String: Any])
        json.removeValue(forKey: "recognition")
        let decoded = try FileCardStore.decoder.decode(
            BusinessCard.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        XCTAssertEqual(decoded.name, "Legacy")
    }
}
