import Foundation

/// Normalization rules applied before any classification happens.
///
/// OCR output for Chinese cards mixes full-width punctuation, stray spaces
/// between CJK glyphs and label prefixes such as `手机：`. Normalizing once, in
/// one place, is what keeps the matchers small and testable.
enum TextNormalizer {
    /// Full-width -> half-width for the characters that appear in real cards.
    static func normalize(_ raw: String) -> String {
        var text = raw
        let map: [Character: Character] = [
            "（": "(", "）": ")", "：": ":", "，": ",", "、": ",",
            "；": ";", "＋": "+", "－": "-", "—": "-", "–": "-",
            "／": "/", "＠": "@", "．": ".", "＜": "<", "＞": ">",
            "［": "[", "］": "]", "｛": "{", "｝": "}", "＊": "*",
            "　": " ",
        ]
        text = String(text.map { map[$0] ?? $0 })
        // Collapse runs of whitespace, drop spaces around CJK punctuation.
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Splits `"Mobile: +86 138..."` into `("Mobile", "+86 138...")`.
    static func splitLabel(_ line: String) -> (label: String?, value: String) {
        guard let colon = line.firstIndex(of: ":") else { return (nil, line) }
        let head = String(line[line.startIndex ..< colon]).trimmingCharacters(in: .whitespaces)
        let tail = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !head.isEmpty, head.count <= 12 else { return (nil, line) }
        return (head, tail)
    }

    /// Removes a leading label from the value if present, e.g. `"Tel: 021-..."`.
    static func strippingKnownLabels(_ line: String) -> String {
        let (label, value) = splitLabel(line)
        guard let label, !value.isEmpty else { return line }
        let known = PhoneClassifier.mobileLabels + PhoneClassifier.officeLabels
            + PhoneClassifier.faxLabels + ["Email", "E-mail", "邮箱", "邮件", "Web", "Website", "网址",
                                           "Add", "Address", "地址", "部门", "Dept", "Dept."]
        let normalizedLabel = label.lowercased().trimmingCharacters(in: .whitespaces)
        if known.contains(where: { $0.lowercased() == normalizedLabel }) {
            return value
        }
        return line
    }

    /// Splits CJK text from adjacent Latin text when they were glued by OCR,
    /// e.g. `"朱宏明Zhu Hongming"` -> `"朱宏明 Zhu Hongming"`.
    static func separateScriptRuns(_ line: String) -> String {
        let scalars = Array(line.unicodeScalars)
        var output = ""
        var index = 0
        while index < scalars.count {
            let current = scalars[index]
            output.unicodeScalars.append(current)
            guard index + 1 < scalars.count else { break }
            let next = scalars[index + 1]
            let currentCJK = isCJK(current)
            let nextCJK = isCJK(next)
            // Only CJK <-> Latin needs a space. CJK next to a digit is normal
            // Chinese typography ("四平路1239号") and must not be rewritten.
            let currentAlpha = isLatinLetter(current)
            let nextAlpha = isLatinLetter(next)
            if (currentCJK && nextAlpha) || (currentAlpha && nextCJK) {
                output.append(" ")
            }
            index += 1
        }
        return output.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func isLatinLetter(_ scalar: Unicode.Scalar) -> Bool {
        (0x41 ... 0x5A).contains(scalar.value) || (0x61 ... 0x7A).contains(scalar.value)
    }

    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00 ... 0x9FFF).contains(scalar.value) || (0x3400 ... 0x4DBF).contains(scalar.value)
    }

    /// Character-level similarity ratio used by the benchmark and by tests.
    static func normalizedLevenshtein(_ lhs: String, _ rhs: String) -> Double {
        let a = Array(lhs.lowercased())
        let b = Array(rhs.lowercased())
        if a.isEmpty && b.isEmpty {
            return 1
        }
        if a.isEmpty || b.isEmpty {
            return 0
        }
        var previous = Array(0 ... b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1 ... a.count {
            current[0] = i
            for j in 1 ... b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        let distance = previous[b.count]
        return 1 - Double(distance) / Double(max(a.count, b.count))
    }
}
