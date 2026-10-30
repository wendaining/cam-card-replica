import Foundation

protocol FieldParsing: Sendable {
    func parse(_ result: OCRResult) -> ParsedCard
}

/// Rule-based field extraction.
///
/// Why not an LLM here (see ADR-0002): the assignment scores *structured
/// extraction quality* and *hallucination rate*, not "did you call a model".
/// Rules are deterministic, auditable (every value carries its evidence),
/// offline and cheap to regression-test. The trade-off is recall on unusual
/// layouts, which is exactly what `docs/reports/ocr-accuracy.md` quantifies.
struct HeuristicFieldParser: FieldParsing {
    struct Config: Sendable {
        /// Below this the field is reported as `nil` rather than guessed (T09).
        var minimumConfidence: Double = 0.5
        /// Below this the UI highlights the field for human review (T11).
        var highlightBelow: Double = 0.78
    }

    var config = Config()

    func parse(_ result: OCRResult) -> ParsedCard {
        let lines = prepare(result)
        guard !lines.isEmpty else { return .empty }

        var used = Set<Int>()
        var parsed = ParsedCard(
            name: nil, company: nil, jobTitle: nil, department: nil,
            phones: [], emails: [], website: nil, address: nil, unassignedLines: []
        )

        let heights = lines.map(\.height).sorted()
        let medianHeight = heights.isEmpty ? 0.02 : heights[heights.count / 2]

        // 1. Name — the visually dominant line that carries no other signal.
        if let index = pickNameCandidate(from: lines, medianHeight: medianHeight) {
            let line = lines[index]
            let ratio = line.height / max(medianHeight, 0.001)
            var value = TextNormalizer.strippingKnownLabels(line.text)
            value = stripHonorifics(value)
            parsed.name = ParsedValue(
                value: value,
                confidence: nameConfidence(ratio: ratio, lineCount: lines.count),
                evidence: String(format: "字号 %.1fx 中位数，无其他字段特征", ratio)
            )
            used.insert(index)
        }

        // 2. Job title
        var matchedOrganizationKeyword = false
        if let index = pickTitleCandidate(from: lines, excluding: used) {
            matchedOrganizationKeyword = true
            let line = lines[index]
            let value = titleValue(from: line)
            parsed.jobTitle = ParsedValue(
                value: value,
                confidence: line.matchedTitle != nil ? 0.9 : 0.72,
                evidence: "命中职位词「\(line.matchedTitle ?? "-")」"
            )
            used.insert(index)
        }

        // 3. Company
        if let index = pickCompanyCandidate(from: lines, excluding: used) {
            matchedOrganizationKeyword = true
            let line = lines[index]
            parsed.company = ParsedValue(
                value: companyValue(from: line),
                confidence: line.hasSuffixCompanyMarker ? 0.9 : 0.78,
                evidence: "命中机构词「\(line.matchedCompany ?? "-")」"
            )
            used.insert(index)
        } else if let index = fallbackCompanyCandidate(from: lines, excluding: used),
                  let name = parsed.name?.value {
            // The line right under the name is usually the organization; keep
            // the confidence modest so the human checks it.
            let line = lines[index]
            parsed.company = ParsedValue(
                value: line.text,
                confidence: 0.62,
                evidence: "位于姓名「\(name)」之后，无机构关键词"
            )
            used.insert(index)
        }

        // 4. Department
        if let index = pickDepartmentCandidate(from: lines, excluding: used) {
            let line = lines[index]
            parsed.department = ParsedValue(
                value: line.text,
                confidence: 0.78,
                evidence: "命中部门词「\(line.matchedDepartment ?? "-")」"
            )
            used.insert(index)
        }

        // 5. Address (may span two lines)
        if let group = pickAddressLines(from: lines) {
            let joined = group.map { TextNormalizer.strippingKnownLabels($0.text) }
                .joined(separator: " ")
            let confidence = group.contains(where: \.hasPostalCode) ? 0.9 : 0.84
            parsed.address = ParsedValue(
                value: joined,
                confidence: confidence,
                evidence: "命中地址特征（\(group.count) 行）"
            )
            group.forEach { used.insert($0.index) }
        }

        // 6. Website
        if let (index, value) = pickWebsite(from: lines) {
            parsed.website = ParsedValue(value: value, confidence: 0.92, evidence: "匹配网址格式")
            if lines[index].phones.isEmpty, lines[index].emails.isEmpty {
                used.insert(index)
            }
        }

        // 7. Emails
        var emailValues: [(String, Int)] = []
        for (index, line) in lines.enumerated() {
            for email in line.emails where !emailValues.contains(where: { $0.0 == email }) {
                emailValues.append((email, index))
            }
        }
        parsed.emails = emailValues.map { email, index in
            if lines[index].phones.isEmpty {
                used.insert(index)
            }
            return ParsedValue(value: email, confidence: 0.96, evidence: "匹配邮箱格式")
        }

        // 8. Phones
        var seenDigits = Set<String>()
        for (index, line) in lines.enumerated() {
            for candidate in line.phones where !seenDigits.contains(candidate.digits) {
                seenDigits.insert(candidate.digits)
                parsed.phones.append(ParsedPhone(
                    kind: candidate.kind,
                    value: ParsedValue(
                        value: candidate.value,
                        confidence: candidate.confidence,
                        evidence: candidate.label.map { "标签「\($0)」" } ?? "号码格式推断"
                    )
                ))
                if line.emails.isEmpty {
                    used.insert(index)
                }
            }
        }

        // 9. Plausibility gate: a page with no contact signal and no
        // organization is not a business card (a meeting note, a menu, a blank
        // page). Reporting nothing is better than reporting a fake contact.
        let hasContact = !parsed.phones.isEmpty || !parsed.emails.isEmpty
            || parsed.website != nil || parsed.address != nil
        // Only a keyword match counts as an organization: the positional
        // fallback below would happily turn "2026 年 10 月" into a company.
        let hasOrganization = matchedOrganizationKeyword
        if !hasContact, !hasOrganization {
            return ParsedCard(
                name: nil, company: nil, jobTitle: nil, department: nil,
                phones: [], emails: [], website: nil, address: nil,
                unassignedLines: lines.map(\.text)
            )
        }

        // 10. Whatever is left is shown verbatim in the review screen.
        parsed.unassignedLines = lines.enumerated()
            .filter { !used.contains($0.offset) }
            .map(\.element.text)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return dropLowConfidence(parsed)
    }

    // MARK: - Preparation

    private struct Line {
        var index: Int
        var text: String
        var height: CGFloat
        var top: CGFloat
        var minX: CGFloat
        var emails: [String] = []
        var websites: [String] = []
        var phones: [PhoneClassifier.Candidate] = []
        var matchedTitle: String?
        var matchedCompany: String?
        var matchedDepartment: String?
        var addressScore: Double = 0
        var hasPostalCode: Bool = false
        var hasSuffixCompanyMarker: Bool = false
        var label: String?
        var labelKind: PhoneKind?
    }

    private func prepare(_ result: OCRResult) -> [Line] {
        let ordered = mergeLabelRows(result.readingOrderedLines)
        var lines: [Line] = []
        for raw in ordered {
            var text = TextNormalizer.normalize(raw.text)
            text = TextNormalizer.separateScriptRuns(text)
            let compact = text.replacingOccurrences(of: " ", with: "")
            guard compact.count >= 2 else { continue }

            // `index` must be the position inside `lines`, not the position in
            // the raw OCR output: empty observations are dropped below, so the
            // two diverge and later `lines[index]` lookups would be wrong.
            var line = Line(
                index: lines.count,
                text: text,
                height: raw.height,
                top: raw.boundingBox.minY,
                minX: raw.boundingBox.minX
            )
            let (label, value) = TextNormalizer.splitLabel(text)
            line.label = label
            line.labelKind = label.flatMap { PhoneClassifier.kind(forLabel: $0) }
            _ = value

            line.emails = matches(KeywordTables.emailRegex, in: text)
            // Parse the whole line: `PhoneClassifier` splits the label itself,
            // and the label is what makes "Tel:" an office number (T10).
            line.phones = PhoneClassifier.candidates(in: text)

            let emailRanges = line.emails
            line.websites = matches(KeywordTables.websiteRegex, in: text).filter { candidate in
                // A domain inside an email address is not a website.
                !emailRanges.contains { $0.contains(candidate) || candidate.contains($0) }
            }

            let keywordText = withoutInternetAddresses(text)
            line.matchedTitle = longestKeyword(in: keywordText, from: KeywordTables.jobTitles)
            line.matchedCompany = longestKeyword(in: keywordText, from: KeywordTables.companyMarkers)
            line.matchedDepartment = longestKeyword(in: keywordText, from: KeywordTables.departmentMarkers)
            let addressText = line.phones.reduce(keywordText) { value, phone in
                value.replacingOccurrences(of: phone.value, with: " ")
            }
            line.addressScore = addressScore(addressText)
            line.hasPostalCode = addressText.range(of: #"(?<!\d)\d{6}(?!\d)"#, options: .regularExpression) != nil
            line.hasSuffixCompanyMarker = hasSuffixMarker(keywordText)
            lines.append(line)
        }
        return lines
    }

    /// Vision sometimes returns `"Mobile:"` and `"+86 138..."` as two separate
    /// observations on the same visual row. Glue them back together.
    private func mergeLabelRows(_ input: [OCRTextLine]) -> [OCRTextLine] {
        var output: [OCRTextLine] = []
        var index = 0
        let allLabels = PhoneClassifier.mobileLabels + PhoneClassifier.officeLabels
            + PhoneClassifier.faxLabels + ["email", "e-mail", "web", "website", "add", "address", "邮箱", "网址", "地址"]

        while index < input.count {
            let current = input[index]
            let text = TextNormalizer.normalize(current.text)
            let isBareLabel = text.hasSuffix(":")
                && allLabels.contains(text.dropLast().lowercased().trimmingCharacters(in: .whitespaces))
            if isBareLabel, index + 1 < input.count {
                let next = input[index + 1]
                let sameRow = abs(next.boundingBox.midY - current.boundingBox.midY) < max(0.02, current.height * 0.6)
                if sameRow {
                    let mergedText = current.text + " " + next.text
                    let box = current.boundingBox.union(next.boundingBox)
                    output.append(OCRTextLine(
                        text: mergedText,
                        boundingBox: box,
                        confidence: min(current.confidence, next.confidence)
                    ))
                    index += 2
                    continue
                }
            }
            output.append(current)
            index += 1
        }
        return output
    }

    // MARK: - Candidates

    private func pickNameCandidate(from lines: [Line], medianHeight: CGFloat) -> Int? {
        struct Scored { var index: Int; var score: Double }
        var scored: [Scored] = []
        for line in lines {
            guard !isStructured(line) else { continue }
            let ratio = line.height / max(medianHeight, 0.001)
            var score = ratio * 2
            if line.text.contains(where: { String($0).isCJK }) {
                score += 0.5
            }
            let words = line.text.split(separator: " ").count
            if words <= 4 {
                score += 0.3
            }
            if line.text.count > 28 {
                score -= 1.0
            }
            if line.text.allSatisfy(\.isNumber) {
                score -= 2.0
            }
            scored.append(Scored(index: line.index, score: score))
        }
        return scored.max { lhs, rhs in
            lhs.score == rhs.score ? lhs.index > rhs.index : lhs.score < rhs.score
        }?.index
    }

    private func pickTitleCandidate(from lines: [Line], excluding used: Set<Int>) -> Int? {
        struct Scored { var index: Int; var score: Double }
        let scored: [Scored] = lines.compactMap { line in
            guard !used.contains(line.index), let title = line.matchedTitle else { return nil }
            if line.addressScore >= 3 {
                return nil
            }
            var score = Double(title.count)
            // "Sierra Legal Partners" contains "Partners" but is an organization
            // name, not a job title.
            if line.hasSuffixCompanyMarker {
                score -= 12
            }
            if line.matchedCompany != nil {
                score -= 3
            }
            if line.text.split(separator: " ").count > 4 {
                score -= 2
            }
            guard score > 0 else { return nil }
            return Scored(index: line.index, score: score)
        }
        return scored.max { lhs, rhs in
            lhs.score == rhs.score ? lhs.index > rhs.index : lhs.score < rhs.score
        }?.index
    }

    private func pickCompanyCandidate(from lines: [Line], excluding used: Set<Int>) -> Int? {
        let candidates = lines.filter { line in
            guard !used.contains(line.index), line.matchedCompany != nil else { return false }
            // An address can contain organization-ish words ("科技园南路").
            if line.addressScore >= 3 || line.hasPostalCode {
                return false
            }
            // "Ocean Freight" matches the marker "Freight" but its department
            // match is longer, so it is a department, not the company.
            if let dept = line.matchedDepartment, let company = line.matchedCompany,
               dept.count > company.count {
                return false
            }
            return true
        }
        return candidates.max { lhs, rhs in
            if lhs.hasSuffixCompanyMarker != rhs.hasSuffixCompanyMarker {
                return rhs.hasSuffixCompanyMarker
            }
            return lhs.height < rhs.height
        }?.index
    }

    private func fallbackCompanyCandidate(from lines: [Line], excluding used: Set<Int>) -> Int? {
        guard let nameIndex = used.min() else { return nil }
        return lines.first {
            guard $0.index > nameIndex, $0.index <= nameIndex + 3,
                  !used.contains($0.index), !isStructured($0) else { return false }
            // Never mistake a labelled contact row for an organization.
            if $0.label != nil {
                return false
            }
            return $0.text.count >= 2 && $0.text.count <= 40
        }?.index
    }

    private func pickDepartmentCandidate(from lines: [Line], excluding used: Set<Int>) -> Int? {
        let candidates = lines.filter { line in
            guard !used.contains(line.index), let dept = line.matchedDepartment else { return false }
            if line.addressScore >= 3 || line.hasPostalCode {
                return false
            }
            guard let company = line.matchedCompany else { return true }
            // "学院" lives in both vocabularies; the department match wins when
            // it is at least as specific as the company match.
            return dept.count >= company.count
        }
        return candidates.max { $0.height < $1.height }?.index
    }

    private func pickAddressLines(from lines: [Line]) -> [Line]? {
        let candidates = lines.filter { $0.addressScore >= 3 || $0.hasPostalCode }
        guard let best = candidates.max(by: { $0.addressScore < $1.addressScore }) else { return nil }
        var group = [best]
        // Addresses often wrap onto the next line.
        for line in lines where line.index > best.index && line.index <= best.index + 1 {
            if line.addressScore >= 2, !group.contains(where: { $0.index == line.index }) {
                group.append(line)
            }
        }
        return group.sorted { $0.index < $1.index }
    }

    private func pickWebsite(from lines: [Line]) -> (Int, String)? {
        var flattened = lines.flatMap { line -> [(Int, String)] in
            let label = line.label?.lowercased() ?? ""
            guard !["email", "e-mail", "邮箱", "邮件"].contains(label) else { return [] }
            let labelledWebsite = ["web", "website", "url", "网址", "网站"].contains(label)
            return line.websites.filter { labelledWebsite || hasWebPrefix($0) }.map { (line.index, $0) }
        }
        if flattened.isEmpty {
            // Fallback: a line that clearly starts with a web prefix even if the
            // TLD is outside the whitelist.
            for line in lines {
                let lowered = line.text.lowercased()
                if hasWebPrefix(lowered) {
                    let value = TextNormalizer.strippingKnownLabels(line.text)
                    if !value.isEmpty {
                        flattened.append((line.index, value))
                    }
                }
            }
        }
        guard !flattened.isEmpty else { return nil }
        // Prefer an explicit www./http(s) form over a bare domain guess.
        return flattened.first { value in
            let lowered = value.1.lowercased()
            return hasWebPrefix(lowered)
        } ?? flattened.first
    }

    private func hasWebPrefix(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.hasPrefix("www.") || lower.hasPrefix("https://") || lower.hasPrefix("http://")
    }
}

// MARK: - Helpers

extension HeuristicFieldParser {
    /// Domains and mailbox names are contact values, not organization evidence.
    private func withoutInternetAddresses(_ text: String) -> String {
        [KeywordTables.emailRegex, KeywordTables.websiteRegex].reduce(text) { value, regex in
            regex.stringByReplacingMatches(
                in: value, range: NSRange(value.startIndex..., in: value), withTemplate: " "
            )
        }
    }

    private func isStructured(_ line: Line) -> Bool {
        if !line.emails.isEmpty || !line.websites.isEmpty {
            return true
        }
        if !line.phones.isEmpty {
            return true
        }
        if line.matchedTitle != nil || line.matchedCompany != nil || line.matchedDepartment != nil {
            return true
        }
        if line.addressScore >= 2 {
            return true
        }
        return false
    }

    private func nameConfidence(ratio: Double, lineCount: Int) -> Double {
        if ratio >= 1.25 {
            return 0.93
        }
        if ratio >= 1.10 {
            return 0.86
        }
        if ratio >= 0.95 {
            return 0.72
        }
        return lineCount > 2 ? 0.58 : 0.5
    }

    private func stripHonorifics(_ value: String) -> String {
        var text = value
        for honorific in KeywordTables.honorifics {
            if text.hasPrefix(honorific + " ") {
                text = String(text.dropFirst(honorific.count + 1))
            }
        }
        return text.trimmingCharacters(in: CharacterSet(charactersIn: " ,，·|"))
    }

    private func stripLabel(_ text: String) -> String {
        let (label, value) = TextNormalizer.splitLabel(text)
        guard label != nil, !value.isEmpty else { return text }
        return value
    }

    private func titleValue(from line: Line) -> String {
        guard let marker = line.matchedTitle else { return line.text }
        // "Professor, ABC University" -> keep only the title segment.
        if line.matchedCompany != nil || line.matchedDepartment != nil {
            let segments = line.text
                .components(separatedBy: CharacterSet(charactersIn: ",，·|/"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if let hit = segments.first(where: { $0.range(of: marker, options: .caseInsensitive) != nil }) {
                return hit
            }
        }
        return TextNormalizer.strippingKnownLabels(line.text)
    }

    private func companyValue(from line: Line) -> String {
        TextNormalizer.strippingKnownLabels(line.text)
    }

    private func addressScore(_ text: String) -> Double {
        var score = 0.0
        let (label, value) = TextNormalizer.splitLabel(text)
        if let label, ["address", "add", "地址"].contains(label.lowercased()), value.nilIfBlank != nil {
            score += 3
        }
        for marker in KeywordTables.addressStrongMarkers where containsKeyword(text, marker) {
            score += 2
        }
        // A street word plus a leading house number is stronger than either alone.
        if score >= 2, text.range(of: #"^\d+[A-Za-z]?(?:-\d+)?\s+"#, options: .regularExpression) != nil {
            score += 1
        }
        for marker in KeywordTables.addressWeakMarkers where containsKeyword(text, marker) {
            score += 1
        }
        if text.range(of: #"(?<!\d)\d{6}(?!\d)"#, options: .regularExpression) != nil {
            score += 1.5
        }
        // German-style compound street names ("Friedrichstrasse") never match a
        // word-boundary marker, so check the common suffixes explicitly.
        let compoundSuffixes = ["strasse", "straße", "weg", "platz", "allee", "gasse"]
        if wordTokens(text).contains(where: { word in compoundSuffixes.contains { word.hasSuffix($0) } }) {
            score += 2
        }
        return score
    }

    private func hasSuffixMarker(_ text: String) -> Bool {
        KeywordTables.companyMarkers.contains { keyword in
            guard !keyword.contains(where: { String($0).isCJK }) else {
                return text.hasSuffix(keyword)
            }
            guard let last = wordTokens(keyword).last else { return false }
            return wordTokens(text).last == last
        }
    }

    private func longestKeyword(in text: String, from table: [String]) -> String? {
        var best: String?
        for keyword in table {
            guard containsKeyword(text, keyword) else { continue }
            if let current = best, current.count >= keyword.count {
                continue
            }
            best = keyword
        }
        return best
    }

    /// CJK markers are matched as substrings ("同济大学" contains "大学"); Latin
    /// markers are matched as whole words, otherwise "Finch" would match "Inc"
    /// and "Manager" would match "AG".
    private func containsKeyword(_ text: String, _ keyword: String) -> Bool {
        if keyword.contains(where: { String($0).isCJK }) {
            return text.contains(keyword)
        }
        let phrase = wordTokens(keyword)
        guard !phrase.isEmpty else { return false }
        let words = wordTokens(text)
        guard words.count >= phrase.count else { return false }
        if phrase.count == 1 {
            return words.contains(phrase[0])
        }
        for start in 0 ... (words.count - phrase.count) {
            if Array(words[start ..< start + phrase.count]) == phrase {
                return true
            }
        }
        return false
    }

    private func wordTokens(_ text: String) -> [String] {
        text.lowercased()
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
    }

    private func matches(_ regex: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { result in
            guard let matchRange = Range(result.range, in: text) else { return nil }
            let value = String(text[matchRange])
                .trimmingCharacters(in: CharacterSet(charactersIn: " .,;:，。；："))
            return value.isEmpty ? nil : value
        }
    }

    private func dropLowConfidence(_ card: ParsedCard) -> ParsedCard {
        var result = card
        if let name = result.name, name.confidence < config.minimumConfidence {
            result.name = nil
        }
        if let company = result.company, company.confidence < config.minimumConfidence {
            result.company = nil
        }
        if let title = result.jobTitle, title.confidence < config.minimumConfidence {
            result.jobTitle = nil
        }
        if let dept = result.department, dept.confidence < config.minimumConfidence {
            result.department = nil
        }
        if let website = result.website, website.confidence < config.minimumConfidence {
            result.website = nil
        }
        if let address = result.address, address.confidence < config.minimumConfidence {
            result.address = nil
        }
        result.phones = result.phones.filter { $0.value.confidence >= config.minimumConfidence }
        result.emails = result.emails.filter { $0.confidence >= config.minimumConfidence }
        return result
    }
}

// MARK: - Test seam

extension HeuristicFieldParser {
    /// Exposed for tests that need to assert the raw evidence pipeline.
    func parse(lines texts: [String], heights: [CGFloat]? = nil) -> ParsedCard {
        let defaultHeights: [CGFloat] = texts.indices.map { index in
            index == 0 ? 0.06 : 0.03
        }
        let lineHeights = heights ?? defaultHeights
        var y: CGFloat = 0.05
        var ocrLines: [OCRTextLine] = []
        for (index, text) in texts.enumerated() {
            let height = index < lineHeights.count ? lineHeights[index] : 0.03
            let box = CGRect(x: 0.06, y: y, width: 0.8, height: height)
            y += height + 0.01
            ocrLines.append(OCRTextLine(text: text, boundingBox: box, confidence: 0.9))
        }
        let result = OCRResult(
            lines: ocrLines,
            rawText: texts.joined(separator: "\n"),
            imageSize: CGSize(width: 1000, height: 640),
            duration: 0,
            languages: ["zh-Hans", "en-US"]
        )
        return parse(result)
    }
}
