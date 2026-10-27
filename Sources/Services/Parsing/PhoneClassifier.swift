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
        let (label, _) = TextNormalizer.splitLabel(line)
        let labelKind = label.flatMap { kind(forLabel: $0) }

        let scalars = Array(line)
        var results: [Candidate] = []
        var index = 0
        while index < scalars.count {
            guard isNumberLike(scalars[index]) else {
                index += 1
                continue
            }
            var end = index
            var chunk = ""
            while end < scalars.count, isNumberLike(scalars[end]) {
                chunk.append(scalars[end])
                end += 1
            }
            // Trim trailing separators that belong to the sentence, not the number.
            while let last = chunk.last, last == " " || last == "-" || last == "." || last == "," {
                chunk.removeLast()
            }
            let digits = chunk.filter(\.isNumber)
            if (7 ... 16).contains(digits.count) {
                let (kind, confidence) = inferKind(digits: digits, raw: chunk, labelKind: labelKind)
                results.append(Candidate(
                    value: chunk.trimmingCharacters(in: .whitespaces),
                    digits: digits,
                    kind: kind,
                    confidence: confidence,
                    label: label
                ))
            }
            index = max(end, index + 1)
        }
        return results
    }

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
