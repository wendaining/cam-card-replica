import Foundation

/// How a phone number is presented on the card.
///
/// CamCard distinguishes mobile / office / fax; T10 requires that a card with
/// all three is classified correctly, so the kind is part of the model rather
/// than a free-form string.
enum PhoneKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case mobile
    case office
    case fax

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .mobile: "手机"
        case .office: "座机"
        case .fax: "传真"
        }
    }

    var systemImage: String {
        switch self {
        case .mobile: "iphone"
        case .office: "phone"
        case .fax: "printer"
        }
    }

    /// Canonical order used by the detail screen and by the vCard exporter.
    var sortOrder: Int {
        switch self {
        case .mobile: 0
        case .office: 1
        case .fax: 2
        }
    }
}

struct PhoneNumber: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var kind: PhoneKind
    var number: String

    init(id: UUID = UUID(), kind: PhoneKind, number: String) {
        self.id = id
        self.kind = kind
        self.number = number
    }

    /// Digits only, used for search and for tel: URLs.
    var dialable: String {
        number.filter { $0.isNumber || $0 == "+" }
    }
}
