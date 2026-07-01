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

    func testUnseededReturnsNil() {
        XCTAssertNil(ZhouYiCorpus.text(forNumber: 44)) // 姤 not in seed
    }
}
