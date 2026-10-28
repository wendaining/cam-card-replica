import Foundation

/// Editable form state for the review / edit screens.
///
/// Everything is a `String` so SwiftUI `TextField` can bind directly; blank
/// strings are converted back to `nil` on save, which is how "empty field"
/// semantically differs from "field with an empty string".
struct CardDraft: Equatable {
    var name: String = ""
    var company: String = ""
    var jobTitle: String = ""
    var department: String = ""
    var phones: [PhoneNumber] = []
    var emails: [String] = []
    var website: String = ""
    var address: String = ""
    var notes: String = ""
    var tags: [String] = []
    var deletedTags: Set<String> = []
    var recognition: RecognitionSnapshot?

    mutating func createTag(named name: String, knownTags: [CardTag]) {
        guard let name = name.nilIfBlank else { return }
        let canonical = knownTags.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.name ?? name
        deletedTags = deletedTags.filter { $0.caseInsensitiveCompare(canonical) != .orderedSame }
        if !tags.contains(where: { $0.caseInsensitiveCompare(canonical) == .orderedSame }) {
            tags.append(canonical)
        }
    }

    mutating func deleteTag(named name: String) {
        deletedTags.insert(name)
        tags.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Confidence reported by the parser per field, used to highlight the
    /// fields a human should double-check (spec 九, T11).
    var confidence: [CardField: Double] = [:]

    /// Which fields the parser was not sure about.
    var lowConfidenceFields: Set<CardField> = []

    init() {}

    init(card: BusinessCard) {
        name = card.name
        company = card.company ?? ""
        jobTitle = card.jobTitle ?? ""
        department = card.department ?? ""
        phones = card.phones
        emails = card.emails
        website = card.website ?? ""
        address = card.address ?? ""
        notes = card.notes ?? ""
        tags = card.tags
        recognition = card.recognition
        rawText = card.rawText
    }

    init(parsed: ParsedCard, rawText: String, ocr: OCRResult? = nil) {
        self.name = parsed.name?.value ?? ""
        self.company = parsed.company?.value ?? ""
        self.jobTitle = parsed.jobTitle?.value ?? ""
        self.department = parsed.department?.value ?? ""
        self.phones = parsed.phones.map { PhoneNumber(kind: $0.kind, number: $0.value.value) }
        self.emails = parsed.emails.map(\.value)
        self.website = parsed.website?.value ?? ""
        self.address = parsed.address?.value ?? ""
        self.notes = ""
        self.tags = []
        self.rawText = rawText
        self.recognition = ocr.map { RecognitionSnapshot(ocr: $0, parsed: parsed) }
    }

    private var rawText: String?

    var storedRawText: String? {
        rawText
    }

    /// Builds the record to persist. `nil` fields stay `nil` — no invention.
    func makeCard(
        id: UUID = UUID(),
        originalImageID: String? = nil,
        processedImageID: String? = nil,
        rawText: String? = nil,
        createdAt: Date = Date()
    ) -> BusinessCard {
        BusinessCard(
            id: id,
            name: name.nilIfBlank ?? "",
            company: company.nilIfBlank,
            jobTitle: jobTitle.nilIfBlank,
            department: department.nilIfBlank,
            phones: phones.filter { !$0.number.trimmingCharacters(in: .whitespaces).isEmpty },
            emails: emails.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            website: website.nilIfBlank,
            address: address.nilIfBlank,
            notes: notes.nilIfBlank,
            tags: tags,
            originalImageID: originalImageID,
            processedImageID: processedImageID,
            rawText: rawText ?? storedRawText,
            recognition: recognition,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }

    /// A draft is savable when it at least identifies who the card belongs to.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func addPhone(kind: PhoneKind = .mobile) {
        phones.append(PhoneNumber(kind: kind, number: ""))
    }

    mutating func removePhones(at offsets: IndexSet) {
        phones = phones.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
    }
}

/// The eight required fields plus the optional ones from spec 7.5.
enum CardField: String, CaseIterable, Identifiable, Sendable {
    case name
    case company
    case jobTitle
    case department
    case mobile
    case office
    case fax
    case email
    case website
    case address
    case notes

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .name: "姓名"
        case .company: "公司"
        case .jobTitle: "职位"
        case .department: "部门"
        case .mobile: "手机"
        case .office: "座机"
        case .fax: "传真"
        case .email: "邮箱"
        case .website: "网站"
        case .address: "地址"
        case .notes: "备注"
        }
    }

    /// Fields the assignment lists as required (7.5).
    static var required: [CardField] {
        [.name, .company, .jobTitle, .mobile, .office, .email, .website, .address]
    }
}
