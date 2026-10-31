import XCTest
@testable import Luo

/// 按卦象查 and the 卦象 grid are pure lookups over the King Wen table. These pin
/// the two ways hand entry can silently lie: six lines resolving to the wrong
/// hexagram, and a 动爻 producing the wrong 变卦.
final class HexagramLookupTests: XCTestCase {

    func testEveryHandEnteredPatternResolvesToItsKingWenNumber() {
        for entry in KingWenTable.allInKingWenOrder {
            let input = HexagramInput(presentBits: entry.bits, changingMask: 0)
            XCTAssertEqual(input.hexagram.number, entry.number, "bits \(entry.bits) should be #\(entry.number)")
            XCTAssertEqual(input.hexagram.name, entry.name)
            XCTAssertEqual(input.hexagram.presentBits, entry.bits)
            XCTAssertNil(input.hexagram.resultingHexagram, "#\(entry.number) with no 动爻 has no 变卦")
        }
        let numbers = Set((0..<64).map { HexagramInput(presentBits: $0, changingMask: 0).hexagram.number })
        XCTAssertEqual(numbers.count, 64, "all 64 six-bit patterns must land on distinct hexagrams")
    }

    func testTogglingALineFlipsOnlyThatLine() {
        var input = HexagramInput.empty
        XCTAssertEqual(input.hexagram.number, 1)                 // 乾
        input.togglePolarity(0)                                  // 初爻 → 阴
        XCTAssertEqual(input.hexagram.presentBits, 0b111110)
        XCTAssertEqual(input.hexagram.number, 44)                // 姤
        input.togglePolarity(5)                                  // 上爻 → 阴
        XCTAssertEqual(input.hexagram.presentBits, 0b011110)
        XCTAssertEqual(input.hexagram.number, 28)                // 大过
        input.togglePolarity(0)
        input.togglePolarity(5)
        XCTAssertEqual(input, .empty)
    }

    func testChangingLinesYieldTheResultingHexagram() {
        for entry in KingWenTable.allInKingWenOrder {
            for i in 0..<6 {
                var input = HexagramInput(presentBits: entry.bits, changingMask: 0)
                input.toggleChanging(i)
                let hex = input.hexagram
                XCTAssertEqual(hex.number, entry.number, "本卦 must not move when a line is marked 动")
                XCTAssertEqual(hex.changingPositions, [i + 1])
                let expected = KingWenTable.info(forBits: entry.bits ^ (1 << i))
                XCTAssertEqual(hex.resultingHexagram?.number, expected.number,
                               "#\(entry.number) 第\(i + 1)爻动 should become #\(expected.number)")
            }
        }
        // Anchors: 乾 all six 动 → 坤; 乾 初九动 → 姤; 泰 初九动 → 升.
        XCTAssertEqual(HexagramInput(presentBits: 0b111111, changingMask: 0b111111).hexagram.resultingHexagram?.number, 2)
        XCTAssertEqual(HexagramInput(presentBits: 0b111111, changingMask: 0b000001).hexagram.resultingHexagram?.number, 44)
        XCTAssertEqual(HexagramInput(presentBits: 0b000111, changingMask: 0b000001).hexagram.resultingHexagram?.number, 46)
    }

    func testTrigramTableCoversAll64Once() {
        let cells = HexagramGrid.rows.flatMap { $0 }
        XCTAssertEqual(cells.count, 64)
        XCTAssertEqual(Set(cells.map(\.number)).count, 64)
        XCTAssertEqual(HexagramGrid.trigrams.map(\.name), ["乾", "兑", "离", "震", "巽", "坎", "艮", "坤"])
        for (r, row) in HexagramGrid.rows.enumerated() {
            XCTAssertEqual(row.count, 8)
            for (c, cell) in row.enumerated() {
                XCTAssertEqual(cell.lower, HexagramGrid.trigrams[r], "row = lower trigram")
                XCTAssertEqual(cell.upper, HexagramGrid.trigrams[c], "column = upper trigram")
                XCTAssertEqual(cell.bits, cell.lower.bits | (cell.upper.bits << 3))
                XCTAssertEqual(KingWenTable.info(forBits: cell.bits).number, cell.number)
            }
        }
        // Anchors: 下乾上乾 = 乾 #1; 下乾上坤 = 泰 #11; 下坤上乾 = 否 #12; 下坤上坤 = 坤 #2.
        XCTAssertEqual(HexagramGrid.rows[0][0].number, 1)
        XCTAssertEqual(HexagramGrid.rows[0][7].number, 11)
        XCTAssertEqual(HexagramGrid.rows[7][0].number, 12)
        XCTAssertEqual(HexagramGrid.rows[7][7].number, 2)
    }
}
