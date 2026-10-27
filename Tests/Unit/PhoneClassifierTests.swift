@testable import CamCardReplica
import XCTest

final class PhoneClassifierTests: XCTestCase {
    func testMainlandMobileIsDetectedWithoutLabel() {
        let candidates = PhoneClassifier.candidates(in: "+86 138 0000 1234")
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.kind, .mobile)
        XCTAssertEqual(candidates.first?.digits, "8613800001234")
    }

    func testLabelDeterminesKind() {
        XCTAssertEqual(PhoneClassifier.candidates(in: "Tel: 021-6000 1234").first?.kind, .office)
        XCTAssertEqual(PhoneClassifier.candidates(in: "手机: +86 138 0000 1234").first?.kind, .mobile)
        XCTAssertEqual(PhoneClassifier.candidates(in: "传真: 021-6000 1235").first?.kind, .fax)
        XCTAssertEqual(PhoneClassifier.candidates(in: "Fax: +44 20 0000 7001").first?.kind, .fax)
    }

    func testAreaCodeNumbersAreOffice() {
        XCTAssertEqual(PhoneClassifier.candidates(in: "021-6000 1234").first?.kind, .office)
        XCTAssertEqual(PhoneClassifier.candidates(in: "400-800-1234").first?.kind, .office)
    }

    func testPostalCodeIsNotAPhone() {
        XCTAssertTrue(PhoneClassifier.candidates(in: "上海市杨浦区四平路1239号 200092").isEmpty)
    }

    func testEmailDigitsAreNotAPhone() {
        XCTAssertTrue(PhoneClassifier.candidates(in: "contact01@example.com").isEmpty)
    }

    func testTwoNumbersOnOneLine() {
        let candidates = PhoneClassifier.candidates(in: "Tel: 021-6000 1234 / 021-6000 1235")
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.allSatisfy { $0.kind == .office })
    }

    func testUnlabelledInternationalNumberIsLowConfidence() {
        let candidate = PhoneClassifier.candidates(in: "+1 415 000 8000").first
        XCTAssertEqual(candidate?.kind, .mobile)
        XCTAssertLessThan(candidate?.confidence ?? 1, 0.7, "Unlabelled international numbers must not be trusted")
    }
}
