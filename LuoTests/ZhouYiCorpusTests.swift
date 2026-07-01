import XCTest
@testable import Luo

final class ZhouYiCorpusTests: XCTestCase {
    func testQianSeeded() {
        let t = ZhouYiCorpus.text(forNumber: 1)
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.guaCi, "元亨利貞")
        XCTAssertEqual(t?.yaoCi.count, 6)
        XCTAssertEqual(t?.yaoCi.first, "初九：潛龍勿用。")
        XCTAssertNotNil(t?.yong) // 用九
    }

    func testKunSeeded() {
        let t = ZhouYiCorpus.text(forNumber: 2)
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.yaoCi.count, 6)
        XCTAssertNotNil(t?.yong) // 用六
    }

    func testOutOfRangeReturnsNil() {
        XCTAssertNil(ZhouYiCorpus.text(forNumber: 0))
        XCTAssertNil(ZhouYiCorpus.text(forNumber: 65))
    }

    /// Full 64-卦 corpus: every King Wen number 1…64 present, well-formed.
    func testAll64PresentAndWellFormed() {
        for n in 1...64 {
            guard let t = ZhouYiCorpus.text(forNumber: n) else {
                return XCTFail("卦 \(n) missing from corpus")
            }
            XCTAssertFalse(t.guaCi.isEmpty, "卦 \(n) 卦辞 empty")
            XCTAssertEqual(t.yaoCi.count, 6, "卦 \(n) 爻辞 count")
            for (i, line) in t.yaoCi.enumerated() {
                XCTAssertTrue(line.contains("："), "卦 \(n) 爻 \(i) missing 爻题")
                XCTAssertTrue(line.hasSuffix("。"), "卦 \(n) 爻 \(i) unterminated")
            }
            // 用九/用六 belong to 乾/坤 only.
            XCTAssertEqual(t.yong != nil, n == 1 || n == 2, "卦 \(n) yong presence")
        }
    }
}
