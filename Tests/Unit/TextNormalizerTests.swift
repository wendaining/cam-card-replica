import XCTest
@testable import CamCardReplica

final class TextNormalizerTests: XCTestCase {
    func testFullWidthPunctuationIsNormalized() {
        XCTAssertEqual(TextNormalizer.normalize("手机：（+86）138"), "手机:(+86)138")
    }

    func testCJKPunctuationBecomesASCII() {
        XCTAssertEqual(TextNormalizer.normalize("姓名：朱宏明，教授"), "姓名:朱宏明,教授")
    }

    func testSplitLabel() {
        let (label, value) = TextNormalizer.splitLabel("Mobile: +86 138 0000 1234")
        XCTAssertEqual(label, "Mobile")
        XCTAssertEqual(value, "+86 138 0000 1234")
    }

    func testSplitLabelIgnoresLongPrefixes() {
        let (label, _) = TextNormalizer.splitLabel("这是一个很长很长很长的一句话: 值")
        XCTAssertNil(label)
    }

    func testScriptRunsAreSeparatedButDigitsStay() {
        XCTAssertEqual(TextNormalizer.separateScriptRuns("朱宏明Zhu Hongming"), "朱宏明 Zhu Hongming")
        XCTAssertEqual(TextNormalizer.separateScriptRuns("四平路1239号"), "四平路1239号")
    }

    func testLevenshteinSimilarity() {
        XCTAssertEqual(TextNormalizer.normalizedLevenshtein("abc", "abc"), 1, accuracy: 0.0001)
        XCTAssertEqual(TextNormalizer.normalizedLevenshtein("abc", "abd"), 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(TextNormalizer.normalizedLevenshtein("", "abc"), 0, accuracy: 0.0001)
    }
}
