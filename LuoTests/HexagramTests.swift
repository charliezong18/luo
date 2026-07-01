import XCTest
@testable import Luo

final class HexagramTests: XCTestCase {
    private func yao(heads: Int) -> Yao {
        Yao(faces: Array(repeating: CoinFace.heads, count: heads)
            + Array(repeating: CoinFace.tails, count: 3 - heads))
    }

    func testSixYoungYangIsQian() {
        let h = Hexagram(yao: Array(repeating: yao(heads: 1), count: 6)) // all yang, none changing
        XCTAssertEqual(h.number, 1)
        XCTAssertEqual(h.name, "乾")
        XCTAssertEqual(h.presentBits, 0b111111)
        XCTAssertTrue(h.changingPositions.isEmpty)
    }

    func testSixYoungYinIsKun() {
        let h = Hexagram(yao: Array(repeating: yao(heads: 2), count: 6)) // all yin, none changing
        XCTAssertEqual(h.number, 2)
        XCTAssertEqual(h.name, "坤")
        XCTAssertEqual(h.presentBits, 0)
    }

    func testBottomUpOrderingIsTai() {
        // bottom 3 yang, top 3 yin -> 泰 (11).
        let yaos = [yao(heads: 1), yao(heads: 1), yao(heads: 1),
                    yao(heads: 2), yao(heads: 2), yao(heads: 2)]
        let h = Hexagram(yao: yaos)
        XCTAssertEqual(h.number, 11)
        XCTAssertEqual(h.name, "泰")
    }

    func testChangingPositionsAreOneBasedBottomUp() {
        // bottom Yao old-yang (changing), rest young; present is still all-... check positions.
        let yaos = [yao(heads: 3), yao(heads: 1), yao(heads: 1),
                    yao(heads: 1), yao(heads: 1), yao(heads: 0)]
        let h = Hexagram(yao: yaos)
        XCTAssertEqual(h.changingPositions, [1, 6]) // bottom old-yang, top old-yin
    }

    func testNoChangingYaoHasNoResulting() {
        let h = Hexagram(yao: Array(repeating: yao(heads: 1), count: 6)) // all young-yang
        XCTAssertNil(h.resultingHexagram)
    }

    func testAllOldYangResultsInKun() {
        let h = Hexagram(yao: Array(repeating: yao(heads: 3), count: 6)) // all old-yang, all changing
        let r = h.resultingHexagram
        XCTAssertEqual(r?.number, 2)
        XCTAssertEqual(r?.name, "坤")
        XCTAssertEqual(r?.changingPositions, []) // 变卦 is static
    }

    func testBottomChangingOnAllYangResultsInGou() {
        // bottom old-yang (changing) + 5 young-yang → 本卦 乾; flip bottom → 姤 #44
        let yaos = [yao(heads: 3)] + Array(repeating: yao(heads: 1), count: 5)
        let r = Hexagram(yao: yaos).resultingHexagram
        XCTAssertEqual(r?.number, 44)
        XCTAssertEqual(r?.name, "姤")
    }

    func testReconstructRoundTrips() {
        // 乾 bottom old-yang + 5 young-yang → 姤 #44 变卦, 动爻 at position 1.
        let original = Hexagram(yao: [yao(heads: 3)] + Array(repeating: yao(heads: 1), count: 5))
        let rebuilt = Hexagram(presentBits: original.presentBits, changingMask: 0b000001)
        XCTAssertEqual(rebuilt.number, original.number)          // 乾 #1
        XCTAssertEqual(rebuilt.name, original.name)
        XCTAssertEqual(rebuilt.changingPositions, [1])
        XCTAssertEqual(rebuilt.resultingHexagram?.number, 44)    // 姤
    }
}
