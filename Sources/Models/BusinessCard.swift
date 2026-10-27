import Foundation

/// The persisted record. Mirrors `docs/spec/data-model.md` 1:1.
///
/// Design notes:
/// - Optional strings mean "the card does not carry this information". The
///   parser must never fabricate a value (T09); `nil` is the honest answer.
/// - Images are referenced by file id, never embedded, so the JSON stays small
///   and a card can be deleted without leaking megabytes (see ADR-0003).
struct BusinessCard: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var company: String?
    var jobTitle: String?
    var department: String?
    var phones: [PhoneNumber]
    var emails: [String]
    var website: String?
    var address: String?
    var notes: String?
    var tags: [String]
    var originalImageID: String?
    var processedImageID: String?
    var rawText: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        company: String? = nil,
        jobTitle: String? = nil,
        department: String? = nil,
        phones: [PhoneNumber] = [],
        emails: [String] = [],
        website: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        originalImageID: String? = nil,
        processedImageID: String? = nil,
        rawText: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.company = company
        self.jobTitle = jobTitle
        self.department = department
        self.phones = phones
        self.emails = emails
        self.website = website
        self.address = address
        self.notes = notes
        self.tags = tags
        self.originalImageID = originalImageID
        self.processedImageID = processedImageID
        self.rawText = rawText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Derived

    var mobilePhones: [PhoneNumber] { phones.filter { $0.kind == .mobile } }
    var officePhones: [PhoneNumber] { phones.filter { $0.kind == .office } }
    var faxNumbers: [PhoneNumber] { phones.filter { $0.kind == .fax } }

    var sortedPhones: [PhoneNumber] {
        phones.sorted { $0.kind.sortOrder < $1.kind.sortOrder }
    }

    /// Subtitle shown in the list: "职位 · 公司", skipping whatever is missing.
    var subtitle: String {
        [jobTitle, company].compactMap { $0?.nilIfBlank }.joined(separator: " · ")
    }

    var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        // Chinese names read better as the last one or two characters.
        if String(first).isCJK, trimmed.count >= 2 {
            return String(trimmed.suffix(2))
        }
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2, let a = parts.first?.first, let b = parts.last?.first {
            return "\(a)\(b)".uppercased()
        }
        return String(first).uppercased()
    }

    /// Text indexed by search (spec 十一: name, company, title, phone, email).
    var searchableText: String {
        ([name, company, jobTitle, department, address, notes, website]
            .compactMap { $0 }
            + phones.map(\.number)
            + emails
            + tags)
            .joined(separator: " ")
            .lowercased()
    }

    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        // Digits-only queries match phones regardless of separators.
        if q.allSatisfy({ $0.isNumber || $0 == "+" }) {
            let needle = q.filter(\.isNumber)
            if phones.contains(where: { $0.number.filter(\.isNumber).contains(needle) }) { return true }
        }
        return searchableText.contains(q)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var isCJK: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
        }
    }
}
