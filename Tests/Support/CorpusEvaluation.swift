@testable import CamCardReplica
import Foundation
import XCTest

struct GroundTruthCorpus: Decodable {
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

        var values: [String: [String]] {
            var result = ["name": [name], "company": company.map { [$0] } ?? [],
                          "jobTitle": jobTitle.map { [$0] } ?? [], "department": department.map { [$0] } ?? [],
                          "emails": emails, "website": website.map { [$0] } ?? [],
                          "address": address.map { [$0] } ?? []]
            for kind in ["mobile", "office", "fax"] {
                result[kind] = phones.filter { $0.kind == kind }.map(\.number)
            }
            return result
        }
    }

    struct Card: Decodable {
        var id: String
        var file: String
        var kind: String
        var lang: String
        var layout: String
        var labels: Bool?
        var fontFile: String?
        var fields: Fields
        var expectedAbsent: [String]
        enum CodingKeys: String, CodingKey {
            case id, file, kind, lang, layout, labels, fields
            case expectedAbsent = "expected_absent"
            case fontFile = "font_file"
        }
    }

    var cards: [Card]

    static func load(bundle: Bundle) throws -> GroundTruthCorpus {
        let url = try XCTUnwrap(bundle.url(
            forResource: "ground_truth",
            withExtension: "json",
            subdirectory: "ground-truth"
        ))
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}

struct FieldComparison: Codable {
    var field: String
    var expected: [String]
    var actual: [String]
    var correct: Bool
    var missing: Int
    var extra: Int
    var absent: Bool {
        expected.isEmpty
    }

    init(field: String, expected: [String], actual: [String]) {
        self.field = field
        self.expected = expected.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.actual = actual.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        func counts(_ values: [String]) -> [String: Int] {
            values.reduce(into: [:]) { result, value in
                result[value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), default: 0] += 1
            }
        }
        let wanted = counts(self.expected), found = counts(self.actual)
        correct = wanted == found
        missing = wanted.reduce(0) { $0 + max(0, $1.value - found[$1.key, default: 0]) }
        extra = found.reduce(0) { $0 + max(0, $1.value - wanted[$1.key, default: 0]) }
    }

    static func compare(_ parsed: ParsedCard, with fields: GroundTruthCorpus.Fields) -> [FieldComparison] {
        var actual: [String: [String]] = [
            "name": parsed.name.map { [$0.value] } ?? [], "company": parsed.company.map { [$0.value] } ?? [],
            "jobTitle": parsed.jobTitle.map { [$0.value] } ?? [],
            "department": parsed.department.map { [$0.value] } ?? [],
            "emails": parsed.emails.map(\.value), "website": parsed.website.map { [$0.value] } ?? [],
            "address": parsed.address.map { [$0.value] } ?? [],
        ]
        for kind in ["mobile", "office", "fax"] {
            actual[kind] = parsed.phones.filter { $0.kind.rawValue == kind }.map(\.value.value)
        }
        return fields.values.keys.sorted().map { FieldComparison(
            field: $0,
            expected: fields.values[$0] ?? [],
            actual: actual[$0] ?? []
        ) }
    }
}
