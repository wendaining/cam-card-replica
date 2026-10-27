@testable import CamCardReplica
import XCTest

final class ContactsExporterTests: XCTestCase {
    private let exporter = ContactsExporter()

    private var card: BusinessCard {
        BusinessCard(
            name: "David Chen",
            company: "ABC Technologies",
            jobTitle: "Technical Director",
            phones: [
                PhoneNumber(kind: .mobile, number: "+1 415 000 1234"),
                PhoneNumber(kind: .office, number: "+1 415 000 8000"),
                PhoneNumber(kind: .fax, number: "+1 415 000 8001"),
            ],
            emails: ["david.chen@example.com"],
            website: "www.abc.example",
            address: "500 Market Street, San Francisco, CA 94105"
        )
    }

    func testNameSplitsForLatinNames() {
        let (given, family) = ContactsExporter.splitName("David Chen")
        XCTAssertEqual(given, "David")
        XCTAssertEqual(family, "Chen")
    }

    func testCJKNameIsNotSplit() {
        let (given, family) = ContactsExporter.splitName("朱宏明")
        XCTAssertEqual(given, "朱宏明")
        XCTAssertEqual(family, "")
    }

    func testContactMappingCarriesEveryField() {
        let contact = exporter.makeContact(from: card)
        XCTAssertEqual(contact.givenName, "David")
        XCTAssertEqual(contact.familyName, "Chen")
        XCTAssertEqual(contact.organizationName, "ABC Technologies")
        XCTAssertEqual(contact.jobTitle, "Technical Director")
        XCTAssertEqual(contact.phoneNumbers.count, 3)
        XCTAssertEqual(contact.emailAddresses.first?.value as String?, "david.chen@example.com")
        XCTAssertEqual(contact.postalAddresses.first?.value.street, "500 Market Street, San Francisco, CA 94105")
        XCTAssertEqual(contact.urlAddresses.first?.value as String?, "https://www.abc.example")
    }

    func testVCardIsGenerated() throws {
        let data = try exporter.vCard(for: card)
        XCTAssertFalse(data.isEmpty)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("David"), "vCard must carry the name")
        XCTAssertTrue(text.contains("ABC Technologies"))
        XCTAssertTrue(text.contains("BEGIN:VCARD"))
    }
}
