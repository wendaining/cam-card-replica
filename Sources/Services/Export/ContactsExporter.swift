import Contacts
import Foundation

/// Uses the system Contacts framework, which the assignment explicitly allows
/// for "calls into external systems" (spec 十).
struct ContactsExporter: ContactExporting {
    private let store = CNContactStore()

    func vCard(for card: BusinessCard) throws -> Data {
        let contact = makeContact(from: card)
        do {
            // iOS exposes the vCard encoder through the serialization class;
            // `CNContactVCardRepresentation` is macOS-only.
            return try CNContactVCardSerialization.data(with: [contact])
        } catch {
            throw ContactExportError.encodingFailed
        }
    }

    func saveToContacts(_ card: BusinessCard) async throws {
        let granted = await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        guard granted else { throw ContactExportError.accessDenied }

        let saveRequest = CNSaveRequest()
        saveRequest.add(makeContact(from: card) as! CNMutableContact, toContainerWithIdentifier: nil)
        do {
            try store.execute(saveRequest)
        } catch {
            throw ContactExportError.encodingFailed
        }
    }

    func makeContact(from card: BusinessCard) -> CNMutableContact {
        let contact = CNMutableContact()
        let (given, family) = Self.splitName(card.name)
        contact.givenName = given
        contact.familyName = family
        contact.organizationName = card.company ?? ""
        contact.jobTitle = card.jobTitle ?? ""
        contact.departmentName = card.department ?? ""

        contact.phoneNumbers = card.phones.map { phone in
            CNLabeledValue(label: Self.label(for: phone.kind), value: CNPhoneNumber(stringValue: phone.number))
        }
        contact.emailAddresses = card.emails.map { email in
            CNLabeledValue(label: CNLabelWork, value: email as NSString)
        }
        if let website = card.website {
            let normalized = website.hasPrefix("http") ? website : "https://\(website)"
            if let url = URL(string: normalized) {
                contact.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: url.absoluteString as NSString)]
            }
        }
        if let address = card.address {
            let postal = CNMutablePostalAddress()
            postal.street = address
            contact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: postal)]
        }
        if let notes = card.notes, !notes.isEmpty {
            contact.note = notes
        }
        return contact
    }

    /// Latin names split into given/family; CJK names stay whole in `givenName`
    /// because Chinese order is family-first and splitting would corrupt them.
    static func splitName(_ name: String) -> (given: String, family: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: { String($0).isCJK }) else { return (trimmed, "") }
        let parts = trimmed.split(separator: " ")
        guard parts.count >= 2 else { return (trimmed, "") }
        let family = String(parts.last!)
        let given = parts.dropLast().joined(separator: " ")
        return (given, family)
    }

    private static func label(for kind: PhoneKind) -> String {
        switch kind {
        case .mobile: return CNLabelPhoneNumberMobile
        case .office: return CNLabelWork
        case .fax: return CNLabelPhoneNumberWorkFax
        }
    }
}
