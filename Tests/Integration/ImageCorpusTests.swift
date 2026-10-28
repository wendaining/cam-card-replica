@testable import CamCardReplica
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
                let target = quad.flatMap { try? corrector.correct(image, quad: $0) } ?? image
                let ocr = try recognizer.recognize(image: target, orientation: .up)
                XCTAssertFalse(ocr.lines.isEmpty, "no OCR on \(card.file)")
                let comparisons = FieldComparison.compare(parser.parse(ocr), with: card.fields)
                XCTAssertEqual(comparisons.count, 10)
                records.append(Record(file: card.file, kind: card.kind, lang: card.lang, layout: card.layout,
                                      labels: card.labels ?? true, fontFile: card.fontFile, comparisons: comparisons))
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
}
