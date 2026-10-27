import XCTest
@testable import CamCardReplica

/// Runs the field parser over the shipped Ground Truth corpus.
///
/// This is the "`Reference Test Suite` for the probabilistic half" the assignment
/// asks for: deterministic, reproducible, and it fails the build when a rule
/// change regresses a field below threshold.
final class ParserBenchmarkTests: XCTestCase {
    private struct GroundTruth: Decodable {
        struct Phone: Decodable { var kind: String; var number: String }
        struct Fields: Decodable {
            var name: String
            var company: String?
            var jobTitle: String?
            var department: String?
            var phones: [Phone]
            var emails: [String]
            var website: String?
            var address: String?
        }
        struct Card: Decodable {
            var id: String
            var file: String
            var kind: String
            var lang: String
            var labels: Bool?
            var fields: Fields
            var expected_absent: [String]
        }
        var cards: [Card]
    }

    private func loadGroundTruth() throws -> GroundTruth {
        guard let url = Bundle(for: Self.self).url(
            forResource: "ground_truth", withExtension: "json", subdirectory: "ground-truth"
        ) else {
            throw XCTSkip("ground_truth.json not bundled")
        }
        return try JSONDecoder().decode(GroundTruth.self, from: Data(contentsOf: url))
    }

    /// Builds the OCR observations the recognizer would produce for a clean
    /// render: one line per visual row, the name at the largest font size.
    private func syntheticOCR(for card: GroundTruth.Card) -> OCRResult {
        var items: [(String, CGFloat)] = [(card.fields.name, 0.062)]
        if let company = card.fields.company { items.append((company, 0.042)) }
        if let title = card.fields.jobTitle { items.append((title, 0.036)) }
        if let department = card.fields.department, !department.isEmpty { items.append((department, 0.026)) }
        let labelled = card.labels ?? true
        for phone in card.fields.phones {
            let label = ["mobile": "Mobile", "office": "Tel", "fax": "Fax"][phone.kind] ?? ""
            items.append((labelled ? "\(label): \(phone.number)" : phone.number, 0.030))
        }
        for email in card.fields.emails {
            items.append((labelled ? "Email: \(email)" : email, 0.030))
        }
        if let website = card.fields.website {
            items.append((labelled ? "Web: \(website)" : website, 0.030))
        }
        if let address = card.fields.address {
            items.append((labelled ? "Add: \(address)" : address, 0.030))
        }

        var y: CGFloat = 0.08
        var lines: [OCRTextLine] = []
        for (text, height) in items {
            lines.append(OCRTextLine(
                text: text,
                boundingBox: CGRect(x: 0.06, y: y, width: 0.7, height: height),
                confidence: 0.95
            ))
            y += height + 0.012
        }
        return OCRResult(
            lines: lines,
            rawText: items.map(\.0).joined(separator: "\n"),
            imageSize: CGSize(width: 1012, height: 638),
            duration: 0,
            languages: ["zh-Hans", "en-US"]
        )
    }

    func testFieldAccuracyMeetsThresholds() throws {
        let groundTruth = try loadGroundTruth()
        let parser = HeuristicFieldParser()

        var correct: [String: Int] = [:]
        var total: [String: Int] = [:]
        var failures: [String] = []

        func record(_ field: String, ok: Bool, detail: String) {
            total[field, default: 0] += 1
            if ok { correct[field, default: 0] += 1 } else { failures.append(detail) }
        }

        for card in groundTruth.cards where card.kind == "flat" {
            let parsed = parser.parse(syntheticOCR(for: card))

            func matches(_ lhs: String?, _ rhs: String?) -> Bool {
                let a = lhs?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
                let b = rhs?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
                return a == b
            }

            record("name", ok: matches(parsed.name?.value, card.fields.name), detail: "\(card.id) name")
            record("company", ok: matches(parsed.company?.value, card.fields.company), detail: "\(card.id) company")
            record("jobTitle", ok: matches(parsed.jobTitle?.value, card.fields.jobTitle), detail: "\(card.id) title")
            record("email", ok: matches(parsed.emails.first?.value, card.fields.emails.first), detail: "\(card.id) email")
            record("website", ok: matches(parsed.website?.value, card.fields.website), detail: "\(card.id) website")
            record("address", ok: matches(parsed.address?.value, card.fields.address), detail: "\(card.id) address")

            for kind in ["mobile", "office", "fax"] {
                let expected = card.fields.phones.first { $0.kind == kind }?.number
                let actual = parsed.phones.first { $0.kind.rawValue == kind }?.value.value
                record("phone_\(kind)", ok: matches(actual, expected), detail: "\(card.id) \(kind)")
            }

            // T09: a field listed as absent must stay nil.
            for absent in card.expected_absent {
                switch absent {
                case "website":
                    record("no_hallucination", ok: parsed.website == nil, detail: "\(card.id) invented website")
                case "company":
                    record("no_hallucination", ok: parsed.company == nil, detail: "\(card.id) invented company")
                default:
                    break
                }
            }
        }

        // Thresholds are deliberately below 100%: the corpus contains unlabelled
        // fax numbers that cannot be told apart from mobiles without inventing
        // information (see docs/reports/ocr-accuracy.md).
        let thresholds: [String: Double] = [
            "name": 0.98,
            "company": 0.98,
            "jobTitle": 0.95,
            "email": 1.0,
            "website": 0.98,
            "address": 0.98,
            "phone_mobile": 0.98,
            "phone_office": 0.95,
            "phone_fax": 0.85,
            "no_hallucination": 1.0,
        ]

        var report = ["field,correct,total,accuracy"]
        for (field, threshold) in thresholds.sorted(by: { $0.key < $1.key }) {
            let hits = correct[field, default: 0]
            let count = total[field, default: 0]
            let accuracy = count == 0 ? 0 : Double(hits) / Double(count)
            report.append(String(format: "%@,%d,%d,%.3f", field, hits, count, accuracy))
            XCTAssertGreaterThanOrEqual(
                accuracy, threshold,
                "\(field) accuracy \(accuracy) below threshold \(threshold). Failures: \(failures.filter { $0.contains(field) }.prefix(5))"
            )
        }
        print(report.joined(separator: "\n"))
    }
}
