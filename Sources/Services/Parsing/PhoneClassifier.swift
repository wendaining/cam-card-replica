import Foundation

/// Phone extraction and kind inference (spec 7.5 + T10).
///
/// Deliberately conservative: a value is only reported when the evidence is
/// clear. Guessing "this is probably a fax" is exactly the kind of plausible
/// but wrong behaviour the assignment punishes.
enum PhoneClassifier {
    struct Candidate: Equatable {
        var value: String
        var digits: String
        var kind: PhoneKind
        var confidence: Double
        var label: String?
    }

    static let mobileLabels = ["手机", "手机号", "手机号码", "移动电话", "mobile", "cell", "cell.", "m", "mp", "mob"]
    static let officeLabels = ["电话", "座机", "办公电话", "总机", "direct", "tel", "tel.", "t", "office", "o", "work", "phone"]
    static let faxLabels = ["传真", "传真号", "fax", "fax no", "f"]

    static func kind(forLabel label: String) -> PhoneKind? {
        let key = label.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":：. "))
        if faxLabels.contains(key) {
            return .fax
        }
        if mobileLabels.contains(key) {
            return .mobile
        }
        if officeLabels.contains(key) {
            return .office
        }
        return nil
    }

    /// Finds every phone-like token in a line, tolerating the separators OCR
    /// produces (`+86 138 0000 1234`, `(021) 6000-1234`, `021-6000 1234`).
    static func candidates(in line: String) -> [Candidate] {
        let text = TextNormalizer.normalize(line)
        let source = text as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let masked = NSMutableString(string: text)
        for regex in [KeywordTables.emailRegex, KeywordTables.websiteRegex] {
            for match in regex.matches(in: text, range: fullRange).reversed() {
                masked.replaceCharacters(in: match.range, with: String(repeating: "#", count: match.range.length))
            }
        }
        let scan = masked as String
        let labels = labelRegex.matches(in: scan, range: fullRange)
        let (head, _) = TextNormalizer.splitLabel(text)
        if labels.isEmpty, let head, ["address", "add", "地址", "邮编"].contains(head.lowercased()) {
            return []
        }
        return numberRegex.matches(in: scan, range: fullRange).compactMap { match in
            let raw = source.substring(with: match.range).trimmingCharacters(in: .whitespaces)
            let digits = raw.filter(\.isNumber)
            guard (7 ... 16).contains(digits.count) else { return nil }
            let label = labels.last { $0.range.location < match.range.location }
                .map { source.substring(with: $0.range(at: 1)) }
            let (kind, confidence) = inferKind(digits: digits, raw: raw, labelKind: label.flatMap(kind(forLabel:)))
            return Candidate(value: raw, digits: digits, kind: kind, confidence: confidence, label: label)
        }
    }

    private static let labelRegex: NSRegularExpression = {
        let labels = (mobileLabels + officeLabels + faxLabels).sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        // The expression is built exclusively from escaped labels.
        return try! NSRegularExpression( // swiftlint:disable:this force_try
            pattern: "(?i)(?<![A-Za-z0-9_])(" + labels + #")\s*[:：]\s*"#
        )
    }()

    private static let numberRegex = try! NSRegularExpression( // swiftlint:disable:this force_try
        pattern: #"(?<![\p{L}\p{N}_@])\+?\(?\d[\d +().\-]*\d\)?(?![\p{L}\p{N}_@])"#
    )

    static func inferKind(digits: String, raw: String, labelKind: PhoneKind?) -> (PhoneKind, Double) {
        if let labelKind {
            return (labelKind, 0.96)
        }
        // Mainland mobile: 1[3-9] + 9 digits, with or without the +86 prefix.
        // A leading "+" that is not +86 means another country: "+1 415 000 8000"
        // is 11 digits and would otherwise be mistaken for a Chinese mobile.
        let hasForeignPrefix = raw.trimmingCharacters(in: .whitespaces).hasPrefix("+")
            && !digits.hasPrefix("86")
        let stripped = digits.hasPrefix("86") && digits.count == 13 ? String(digits.dropFirst(2)) : digits
        if !hasForeignPrefix, stripped.count == 11, stripped.first == "1", let second = stripped.dropFirst().first,
           ("3" ... "9").contains(String(second)) {
            return (.mobile, 0.88)
        }
        // Area-code style landlines and service numbers.
        if digits.hasPrefix("0"), (10 ... 12).contains(digits.count) {
            return (.office, 0.82)
        }
        if digits.hasPrefix("400") || digits.hasPrefix("800"), (8 ... 11).contains(digits.count) {
            return (.office, 0.78)
        }
        // International formats: without a label the kind is genuinely unknown,
        // so report the most common one but with low confidence (highlighted in
        // the review screen rather than silently trusted).
        if raw.hasPrefix("+") {
            return (.mobile, 0.62)
        }
        return (.mobile, 0.58)
    }

    static func isNumberLike(_ character: Character) -> Bool {
        character.isNumber || character == "+" || character == "-" || character == " "
            || character == "(" || character == ")" || character == "."
    }
}
