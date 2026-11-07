@testable import CamCardReplica
import CryptoKit
import ImageIO
import XCTest

/// Real image measurements are separate from ideal-text acceptance thresholds.
final class ImageCorpusTests: XCTestCase {
    struct Record: Codable {
        var file: String
        var kind: String
        var lang: String
        var layout: String
        var labels: Bool
        var fontFile: String?
        var comparisons: [FieldComparison]
        var sourceSHA256: String
        var processedImageFile: String
        var processedImageSHA256: String
        var detectedCorners: [CGPoint]
        var processingMode: String
        var ocr: OCRResult
        var parsed: ParsedCard
    }

    func testEvidenceRoundTripKeepsRawOCRAndInitialFields() throws {
        var ocr = OCRResult.empty
        ocr.rawText = "David Chen\nExample Company"
        ocr.lines = [OCRTextLine(
            text: "David Chen", boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.1), confidence: 0.73
        )]
        var parsed = ParsedCard.empty
        parsed.name = ParsedValue(value: "David Chen", confidence: 0.72, evidence: "line 0: name candidate")
        let payload: [String: Any] = try [
            "file": "sample.png", "kind": "flat", "lang": "en", "layout": "left", "labels": true,
            "comparisons": [], "sourceSHA256": String(repeating: "a", count: 64),
            "processedImageSHA256": String(repeating: "b", count: 64),
            "processedImageFile": "processed-sample.png", "detectedCorners": [], "processingMode": "whole-image",
            "ocr": JSONSerialization.jsonObject(with: JSONEncoder().encode(ocr)),
            "parsed": JSONSerialization.jsonObject(with: JSONEncoder().encode(parsed)),
        ]
        let record = try JSONDecoder().decode(Record.self, from: JSONSerialization.data(withJSONObject: payload))
        let restored = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        let savedOCR = restored["ocr"] as? [String: Any]
        XCTAssertEqual(savedOCR?["rawText"] as? String, ocr.rawText)
        XCTAssertEqual((savedOCR?["lines"] as? [[String: Any]])?.count, 1)
        let savedName = (restored["parsed"] as? [String: Any])?["name"] as? [String: Any]
        XCTAssertEqual(savedName?["evidence"] as? String, parsed.name?.evidence)
        XCTAssertEqual(savedName?["confidence"] as? Double, 0.72)
        XCTAssertEqual(restored["sourceSHA256"] as? String, String(repeating: "a", count: 64))
        XCTAssertEqual(restored["processedImageFile"] as? String, "processed-sample.png")
    }

    func testCompleteCollectionsCountMissingExtraAndAbsentValues() {
        let missing = FieldComparison(
            field: "emails",
            expected: ["one@demo.example", "two@demo.example"],
            actual: ["one@demo.example"]
        )
        XCTAssertFalse(missing.correct)
        XCTAssertEqual(missing.missing, 1)
        XCTAssertEqual(missing.extra, 0)
        let extra = FieldComparison(field: "mobile", expected: ["13800000000"], actual: ["13800000000", "13900000000"])
        XCTAssertFalse(extra.correct)
        XCTAssertEqual(extra.extra, 1)
        let absent = FieldComparison(field: "address", expected: [], actual: ["Invented"])
        XCTAssertTrue(absent.absent)
        XCTAssertFalse(absent.correct)
        XCTAssertEqual(absent.extra, 1)
        let blank = FieldComparison(field: "department", expected: [" "], actual: [])
        XCTAssertTrue(blank.absent)
        XCTAssertTrue(blank.correct)
    }

    func testEveryCorpusImageIsComparedAgainstGroundTruth() throws {
        let bundle = Bundle(for: Self.self)
        let truth = try GroundTruthCorpus.load(bundle: bundle)
        let directory = try XCTUnwrap(bundle.url(forResource: "cards", withExtension: nil))
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { ["jpg", "png"].contains($0.pathExtension.lowercased()) }
        XCTAssertEqual(Set(files.map(\.lastPathComponent)), Set(truth.cards.map(\.file)))
        let detector = VisionCardDetector(), corrector = CoreImageCardCorrector()
        let recognizer = VisionTextRecognizer(), parser = HeuristicFieldParser()
        var records: [Record] = []
        for card in truth.cards {
            try autoreleasepool {
                let data = try Data(contentsOf: directory.appendingPathComponent(card.file))
                let image = try XCTUnwrap(ImageCoding.cgImage(from: data), card.file)
                let quad = try detector.detectCard(in: image, orientation: .up)
                let corrected = quad.flatMap { try? corrector.correct(image, quad: $0) }
                let target = corrected ?? image
                let ocr = try recognizer.recognize(image: target, orientation: .up)
                XCTAssertFalse(ocr.lines.isEmpty, "no OCR on \(card.file)")
                let parsed = parser.parse(ocr)
                let comparisons = FieldComparison.compare(parsed, with: card.fields)
                XCTAssertEqual(comparisons.count, 10)
                let png = try pngData(from: target)
                let imageFile = "processed-" + URL(fileURLWithPath: card.file).deletingPathExtension()
                    .lastPathComponent + ".png"
                let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                attachment.name = imageFile
                attachment.lifetime = .keepAlways
                add(attachment)
                records.append(Record(file: card.file, kind: card.kind, lang: card.lang, layout: card.layout,
                                      labels: card.labels ?? true, fontFile: card.fontFile, comparisons: comparisons,
                                      sourceSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                                      processedImageFile: imageFile,
                                      processedImageSHA256: SHA256.hash(data: png).map { String(format: "%02x", $0) }
                                          .joined(),
                                      detectedCorners: quad?.points ?? [],
                                      processingMode: corrected != nil ? "detected-quad" : "whole-image",
                                      ocr: ocr, parsed: parsed))
            }
        }
        XCTAssertEqual(records.count, truth.cards.count)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let json = try String(decoding: encoder.encode(records), as: UTF8.self)
        let attachment = XCTAttachment(string: json)
        attachment.name = "image-corpus-evaluation.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("CORPUS_JSON_BEGIN\n" + json + "\nCORPUS_JSON_END")
    }

    private func pngData(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
