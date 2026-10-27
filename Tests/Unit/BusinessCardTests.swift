import XCTest
@testable import CamCardReplica

final class BusinessCardTests: XCTestCase {
    private func makeCard() -> BusinessCard {
        BusinessCard(
            name: "朱宏明",
            company: "同济大学",
            jobTitle: "教授",
            phones: [
                PhoneNumber(kind: .mobile, number: "+86 138 0000 1234"),
                PhoneNumber(kind: .office, number: "021-6000 1234"),
            ],
            emails: ["zhuhongming@example.com"],
            tags: ["Conference"]
        )
    }

    func testSubtitleSkipsMissingFields() {
        var card = makeCard()
        XCTAssertEqual(card.subtitle, "教授 · 同济大学")
        card.jobTitle = nil
        XCTAssertEqual(card.subtitle, "同济大学")
        card.company = nil
        XCTAssertEqual(card.subtitle, "")
    }

    func testSearchMatchesNameCompanyTitlePhoneAndEmail() {
        let card = makeCard()
        XCTAssertTrue(card.matches(query: "朱宏明"))
        XCTAssertTrue(card.matches(query: "同济"))
        XCTAssertTrue(card.matches(query: "教授"))
        XCTAssertTrue(card.matches(query: "1380000"))
        XCTAssertTrue(card.matches(query: "zhuhongming@example.com"))
        XCTAssertTrue(card.matches(query: "conference"), "tags are searchable")
        XCTAssertFalse(card.matches(query: "清华"))
    }

    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(makeCard().matches(query: "   "))
    }

    func testInitialsForCJKAndLatin() {
        XCTAssertEqual(BusinessCard(name: "朱宏明").initials, "宏明")
        XCTAssertEqual(BusinessCard(name: "David Chen").initials, "DC")
    }

    func testSortedPhonesFollowKindOrder() {
        let card = makeCard()
        XCTAssertEqual(card.sortedPhones.map(\.kind), [.mobile, .office])
    }
}
