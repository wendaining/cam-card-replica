import XCTest
@testable import CamCardReplica

/// Runs the real Vision pipeline over the bundled fixture cards.
///
/// This is the second half of the accuracy story: `ParserBenchmarkTests` measures
/// "text -> fields" with perfect text, this one measures the whole chain
/// "image -> OCR -> fields" on real renders (and two photographed variants).
final class VisionOCRTests: XCTestCase {
    private let recognizer = VisionTextRecognizer()
    private let detector = VisionCardDetector()
    private let parser = HeuristicFieldParser()

    private func fixtureDirectory() throws -> URL {
        guard let url = Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil) else {
            throw XCTSkip("Fixtures not bundled")
        }
        return url
    }

    func testFixturesProduceStructuredFields() throws {
        let directory = try fixtureDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { ["jpg", "png", "jpeg"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertFalse(files.isEmpty)

        print("file,lines,name,company,phones,mobile,office,fax,email,website")
        for file in files {
            let data = try Data(contentsOf: file)
            guard let image = ImageCoding.cgImage(from: data) else {
                XCTFail("cannot decode \(file.lastPathComponent)")
                continue
            }
            let quad = (try? detector.detectCard(in: image, orientation: .up)) ?? nil
            let cropped = (try? ImageCoding.cgImage(from: ImageCoding.jpegData(from: image) ?? data)) ?? image
            let target = quad.flatMap { try? CoreImageCardCorrector().correct(cropped, quad: $0) } ?? cropped
            let ocr = try recognizer.recognize(image: target, orientation: .up)
            let parsed = parser.parse(ocr)

            print([
                file.lastPathComponent,
                "\(ocr.lines.count)",
                parsed.name?.value ?? "-",
                parsed.company?.value ?? "-",
                "\(parsed.phones.count)",
                parsed.phones.first { $0.kind == .mobile }?.value.value ?? "-",
                parsed.phones.first { $0.kind == .office }?.value.value ?? "-",
                parsed.phones.first { $0.kind == .fax }?.value.value ?? "-",
                parsed.emails.first?.value ?? "-",
                parsed.website?.value ?? "-",
            ].joined(separator: "|"))

            XCTAssertFalse(parsed.name?.value.isEmpty ?? true, "\(file.lastPathComponent): no name")
        }
    }

    /// Character recall against the Ground Truth text, per fixture.
    func testTextRecallOnFixtures() throws {
        let directory = try fixtureDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { ["jpg", "png", "jpeg"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var recalls: [Double] = []
        for file in files {
            let data = try Data(contentsOf: file)
            guard let image = ImageCoding.cgImage(from: data) else { continue }
            let ocr = try recognizer.recognize(image: image, orientation: .up)
            let haystack = ocr.rawText.replacingOccurrences(of: " ", with: "")
            let expected = try expectedText(for: file.deletingPathExtension().lastPathComponent)
            guard !expected.isEmpty else { continue }
            let hits = expected.filter { needle in haystack.contains(needle) }.count
            recalls.append(Double(hits) / Double(expected.count))
        }
        XCTAssertFalse(recalls.isEmpty)
        let average = recalls.reduce(0, +) / Double(recalls.count)
        print("text recall per fixture:", recalls.map { String(format: "%.2f", $0) })
        print("average text recall:", String(format: "%.2f", average))
        XCTAssertGreaterThan(average, 0.7, "Vision should read most of a clean render")
    }

    private func expectedText(for fixtureName: String) throws -> [String] {
        guard let url = Bundle(for: Self.self).url(
            forResource: "ground_truth", withExtension: "json", subdirectory: "ground-truth"
        ) else { return [] }
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let cards = json?["cards"] as? [[String: Any]] ?? []
        let base = fixtureName.replacingOccurrences(of: "-photo", with: "")
        guard let card = cards.first(where: { ($0["id"] as? String) == base }) else { return [] }
        let present = card["present_text"] as? [String] ?? []
        return present.map { $0.replacingOccurrences(of: " ", with: "") }
    }
}
