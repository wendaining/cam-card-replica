@testable import CamCardReplica
import Contacts
import XCTest

@MainActor
final class VCardDocumentTests: XCTestCase {
    func testShareDocumentReadsEditedFieldsAndRoundTripsEveryMappedField() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = CardLibraryModel(store: InMemoryCardStore())
        var card = try model.add(BusinessCard(name: "David Chen", company: "Before"))
        let before = try VCardDocument(card: card).writeFile(in: root)
        card.company = "Review Company"
        card.jobTitle = "Engineer"
        card.phones = [PhoneNumber(kind: .office, number: "021-60000000")]
        card.emails = ["review@demo.example"]
        card.website = "https://demo.example"
        card.address = "Review Street 1"
        try model.update(card)
        let edited = try XCTUnwrap(model.card(id: card.id))
        let after = try VCardDocument(card: edited).writeFile(in: root)
        XCTAssertNotEqual(before, after)
        let contact = try XCTUnwrap(CNContactVCardSerialization.contacts(with: Data(contentsOf: after)).first)
        XCTAssertEqual(contact.organizationName, "Review Company")
        XCTAssertEqual(contact.jobTitle, "Engineer")
        XCTAssertEqual(contact.givenName, "David")
        XCTAssertEqual(contact.familyName, "Chen")
        XCTAssertEqual(contact.phoneNumbers.first?.value.stringValue, "021-60000000")
        XCTAssertEqual(contact.emailAddresses.first?.value as String?, "review@demo.example")
        XCTAssertEqual(contact.postalAddresses.first?.value.street, "Review Street 1")
        XCTAssertEqual(contact.urlAddresses.first?.value as String?, "https://demo.example")
        XCTAssertFalse(try String(decoding: Data(contentsOf: before), as: UTF8.self).contains("Review Company"))
    }

    func testSameNameExportsDoNotOverwriteEachOther() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try VCardDocument(card: BusinessCard(name: "Same", company: "One")).writeFile(in: root)
        let second = try VCardDocument(card: BusinessCard(name: "Same", company: "Two")).writeFile(in: root)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(try String(decoding: Data(contentsOf: first), as: UTF8.self).contains("One"))
    }
}
