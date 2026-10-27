@testable import CamCardReplica
import XCTest

/// Guards the regex/token tables that the parser depends on. These are the only
/// `try!` in the codebase, so they get an explicit test that would fail the
/// build if a pattern were ever edited into something invalid.
final class KeywordTablesTests: XCTestCase {
    func testEmailRegexMatchesRealisticAddresses() {
        let regex = KeywordTables.emailRegex
        let samples = [
            "david.chen@example.org",
            "biz08@example.com",
            "first_last+tag@mail.example.net",
        ]
        for sample in samples {
            let range = NSRange(sample.startIndex..., in: sample)
            XCTAssertNotNil(regex.firstMatch(in: sample, range: range), "should match \(sample)")
        }
        XCTAssertNil(regex.firstMatch(in: "no email here", range: NSRange(location: 0, length: 13)))
    }

    func testWebsiteRegexMatchesDomains() {
        let regex = KeywordTables.websiteRegex
        let samples = ["www.example01.com", "https://abc.example", "northwind.example"]
        for sample in samples {
            let range = NSRange(sample.startIndex..., in: sample)
            XCTAssertNotNil(regex.firstMatch(in: sample, range: range), "should match \(sample)")
        }
    }

    func testTitleAndCompanyVocabulariesAreDisjointEnough() {
        // "Partners" is a company suffix, "Partner" a title; the parser relies on
        // both being present so it can pick the right one by position.
        XCTAssertTrue(KeywordTables.companyMarkers.contains("Partners"))
        XCTAssertTrue(KeywordTables.jobTitles.contains("Partner"))
        XCTAssertTrue(KeywordTables.companyMarkers.contains("University"))
        XCTAssertTrue(KeywordTables.departmentMarkers.contains("School"))
    }
}
