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
}
