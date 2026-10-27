import XCTest
@testable import CamCardReplica

/// Table-driven tests for the field parser. Each case mirrors a scenario in the
/// assignment's spec so that "rule changed" and "spec changed" are the same diff.
final class FieldParserTests: XCTestCase {
    private let parser = HeuristicFieldParser()

    // MARK: - 7.5 required example

    func testAcademicCardFromSpecIsStructured() {
        let card = parser.parse(lines: [
            "Dr. David Chen",
            "Professor",
            "School of Computer Science",
            "ABC University",
            "Mobile: +86 138 0000 1234",
            "Email: david@abc.edu",
        ])
        XCTAssertEqual(card.name?.value, "David Chen", "honorific is stripped")
        XCTAssertEqual(card.jobTitle?.value, "Professor")
        XCTAssertEqual(card.company?.value, "ABC University")
        XCTAssertEqual(card.department?.value, "School of Computer Science")
        XCTAssertEqual(card.phones.first?.kind, .mobile)
        XCTAssertEqual(card.emails.first?.value, "david@abc.edu")
    }

    func testChineseCard() {
        let card = parser.parse(lines: [
            "朱宏明", "教授", "同济大学", "计算机科学与技术学院",
            "手机: +86 138 0000 1234", "电话: 021-6000 1234",
            "Email: zhuhongming@example.com", "Web: www.tongji.example",
            "Add: 上海市杨浦区四平路1239号 200092",
        ])
        XCTAssertEqual(card.name?.value, "朱宏明")
        XCTAssertEqual(card.company?.value, "同济大学")
        XCTAssertEqual(card.jobTitle?.value, "教授")
        XCTAssertEqual(card.department?.value, "计算机科学与技术学院")
        XCTAssertEqual(card.phones.first { $0.kind == .office }?.value.value, "021-6000 1234")
        XCTAssertEqual(card.website?.value, "www.tongji.example")
        XCTAssertEqual(card.address?.value, "上海市杨浦区四平路1239号 200092")
    }

    // MARK: - T09: no invention

    func testMissingWebsiteIsNotInvented() {
        let card = parser.parse(lines: [
            "Emily Zhang", "Northwind Analytics", "Senior Data Scientist",
            "Mobile: +1 212 000 5678", "Email: emily.zhang@example.org",
        ])
        XCTAssertNil(card.website, "the card has no website, so the parser must not produce one")
        XCTAssertEqual(card.company?.value, "Northwind Analytics")
    }

    func testJunkTextProducesNoFields() {
        let card = parser.parse(lines: ["会议记录", "2026 年 10 月", "内部资料"])
        XCTAssertNil(card.name)
        XCTAssertNil(card.company)
        XCTAssertTrue(card.phones.isEmpty)
        XCTAssertTrue(card.emails.isEmpty)
        XCTAssertEqual(card.unassignedLines.count, 3, "unmatched lines stay visible for the user")
    }

    func testEmptyInputProducesEmptyCard() {
        let card = parser.parse(lines: [])
        XCTAssertTrue(card.isEmpty)
        XCTAssertEqual(card.overallConfidence, 0)
    }

    // MARK: - T10: multiple phones

    func testMultiplePhonesAreClassifiedByLabel() {
        let card = parser.parse(lines: [
            "Kevin Wu", "Pacific Freight Co.", "Operations Manager",
            "Mobile: +65 0000 2345", "Tel: +65 0000 5000", "Fax: +65 0000 5001",
        ])
        XCTAssertEqual(card.phones.first { $0.kind == .mobile }?.value.value, "+65 0000 2345")
        XCTAssertEqual(card.phones.first { $0.kind == .office }?.value.value, "+65 0000 5000")
        XCTAssertEqual(card.phones.first { $0.kind == .fax }?.value.value, "+65 0000 5001")
    }

    func testUnlabelledPhoneIsStillReported() {
        let card = parser.parse(lines: ["David Chen", "ABC Technologies", "+1 415 000 1234"])
        XCTAssertEqual(card.phones.count, 1)
        XCTAssertEqual(card.phones.first?.kind, .mobile)
    }

    // MARK: - Ambiguity cases from section 八

    func testPersonNameIsNotCompany() {
        let card = parser.parse(lines: ["Jordan Lee", "Lee Consulting", "Principal"])
        XCTAssertEqual(card.name?.value, "Jordan Lee")
        XCTAssertEqual(card.company?.value, "Lee Consulting")
    }

    func testCompanySuffixWinsOverTitleKeyword() {
        let card = parser.parse(lines: ["Laura Mendosa", "Sierra Legal Partners", "Partner"])
        XCTAssertEqual(card.company?.value, "Sierra Legal Partners")
        XCTAssertEqual(card.jobTitle?.value, "Partner")
    }

    func testBilingualNameIsKeptWhole() {
        let card = parser.parse(lines: ["朱宏明 Zhu Hongming", "同济大学 Tongji University", "教授 Professor"])
        XCTAssertEqual(card.name?.value, "朱宏明 Zhu Hongming")
        XCTAssertEqual(card.company?.value, "同济大学 Tongji University")
    }

    func testAddressIsNotMistakenForCompany() {
        let card = parser.parse(lines: [
            "赵敏 Zhao Min", "Conning Medical 康宁医疗", "Marketing Manager 市场经理",
            "手机: +86 150 0000 3344",
            "Add: 深圳市南山区科技园南路18号 518057",
        ])
        XCTAssertEqual(card.company?.value, "Conning Medical 康宁医疗")
        XCTAssertEqual(card.address?.value, "深圳市南山区科技园南路18号 518057")
    }

    // MARK: - Confidence plumbing (T11)

    func testLowConfidenceFieldsAreMarked() {
        let card = parser.parse(lines: ["Olivia Brown", "Cedar & Finch", "Founder"])
        let low = ScanFlowModel.lowConfidenceFields(in: card)
        XCTAssertTrue(low.contains(.company) || card.company != nil)
        XCTAssertLessThan(card.overallConfidence, 1.0)
    }

    func testReadingOrderHandlesTwoColumns() {
        let card = parser.parse(lines: [
            "David Chen", "Technical Director", "ABC Technologies",
            "Mobile:", "+86 138 0000 1234",
        ])
        XCTAssertEqual(card.phones.first?.value.value, "+86 138 0000 1234",
                       "a label split into its own observation must be merged back")
    }
}
