import Foundation

/// Immutable pre-correction evidence; optional for records created by older versions.
struct RecognitionSnapshot: Codable, Hashable, Sendable {
    var ocr: OCRResult
    var parsed: ParsedCard
}

extension ParsedCard {
    var explanations: [(title: String, value: ParsedValue)] {
        let fields: [(String, ParsedValue?)] = [
            ("姓名", name), ("公司", company), ("职位", jobTitle), ("部门", department),
            ("网站", website), ("地址", address),
        ]
        return fields.compactMap { title, value in value.map { (title, $0) } }
            + phones.map { ($0.kind.displayName, $0.value) }
            + emails.map { ("邮箱", $0) }
    }
}
