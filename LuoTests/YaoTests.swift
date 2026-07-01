import XCTest
@testable import Luo

final class YaoTests: XCTestCase {
    private func yao(heads: Int) -> Yao {
        let faces = Array(repeating: CoinFace.heads, count: heads)
            + Array(repeating: CoinFace.tails, count: 3 - heads)
        return Yao(faces: faces)
    }

    func testThreeHeadsIsOldYang() {
        let y = yao(heads: 3)
        XCTAssertEqual(y.kind, .oldYang)
        XCTAssertTrue(y.isYang)
        XCTAssertTrue(y.isChanging)
    }

    func testTwoHeadsIsYoungYin() {
        let y = yao(heads: 2)
        XCTAssertEqual(y.kind, .youngYin)
        XCTAssertFalse(y.isYang)
        XCTAssertFalse(y.isChanging)
    }

    func testOneHeadIsYoungYang() {
        let y = yao(heads: 1)
        XCTAssertEqual(y.kind, .youngYang)
        XCTAssertTrue(y.isYang)
        XCTAssertFalse(y.isChanging)
    }

    func testZeroHeadsIsOldYin() {
        let y = yao(heads: 0)
        XCTAssertEqual(y.kind, .oldYin)
        XCTAssertFalse(y.isYang)
        XCTAssertTrue(y.isChanging)
    }

    func testStaticYangLine() {
        let y = Yao(isYang: true)
        XCTAssertTrue(y.isYang)
        XCTAssertFalse(y.isChanging)
        XCTAssertEqual(y.kind, .youngYang)
        XCTAssertEqual(y.glyph, "⚊")
    }

    func testStaticYinLine() {
        let y = Yao(isYang: false)
        XCTAssertFalse(y.isYang)
        XCTAssertFalse(y.isChanging)
        XCTAssertEqual(y.kind, .youngYin)
        XCTAssertEqual(y.glyph, "⚋")
    }

    func testFullFactoryAllCombos() {
        XCTAssertEqual(Yao(isYang: true,  isChanging: true).kind,  .oldYang)
        XCTAssertEqual(Yao(isYang: true,  isChanging: false).kind, .youngYang)
        XCTAssertEqual(Yao(isYang: false, isChanging: true).kind,  .oldYin)
        XCTAssertEqual(Yao(isYang: false, isChanging: false).kind, .youngYin)
        XCTAssertTrue(Yao(isYang: true, isChanging: true).isChanging)
        XCTAssertFalse(Yao(isYang: false, isChanging: false).isChanging)
    }
}
