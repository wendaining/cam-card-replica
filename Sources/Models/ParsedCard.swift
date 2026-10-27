import Foundation

/// A single extracted value plus the evidence that produced it. The evidence
/// strings are surfaced in the review screen ("为什么这么填") and logged in the
/// benchmark output, which is what makes the parser auditable.
struct ParsedValue: Equatable, Sendable {
    var value: String
    var confidence: Double
    var evidence: String

    init(value: String, confidence: Double, evidence: String) {
        self.value = value
        self.confidence = confidence
        self.evidence = evidence
    }
}

struct ParsedPhone: Equatable, Sendable {
    var kind: PhoneKind
    var value: ParsedValue
}

/// Parser output before a human confirms it. Nothing here is persisted as-is:
/// `CardDraft(parsed:rawText:)` turns it into editable state (spec 九).
struct ParsedCard: Equatable, Sendable {
    var name: ParsedValue?
    var company: ParsedValue?
    var jobTitle: ParsedValue?
    var department: ParsedValue?
    var phones: [ParsedPhone]
    var emails: [ParsedValue]
    var website: ParsedValue?
    var address: ParsedValue?
    /// Lines the parser could not attribute to any field; shown as-is so the
    /// user can copy from them instead of guessing.
    var unassignedLines: [String]

    static let empty = ParsedCard(
        name: nil, company: nil, jobTitle: nil, department: nil,
        phones: [], emails: [], website: nil, address: nil, unassignedLines: []
    )

    var isEmpty: Bool {
        name == nil && company == nil && jobTitle == nil && phones.isEmpty
            && emails.isEmpty && website == nil && address == nil
    }

    /// Mean confidence over the eight fields the assignment requires.
    var overallConfidence: Double {
        let values = [
            name?.confidence, company?.confidence, jobTitle?.confidence,
            phones.first(where: { $0.kind == .mobile })?.value.confidence,
            emails.first?.confidence, website?.confidence, address?.confidence,
        ].compactMap { $0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
