import XCTest
@testable import Luo

final class KingWenTableTests: XCTestCase {
    // bits helper: lines bottom→top, true = yang.
    private func bits(_ lines: [Bool]) -> Int {
        var v = 0
        for (i, yang) in lines.enumerated() where yang { v |= (1 << i) }
        return v
    }

    func testAllYangIsQian() {
        let info = KingWenTable.info(forBits: bits([true, true, true, true, true, true]))
        XCTAssertEqual(info.number, 1)
        XCTAssertEqual(info.name, "乾")
    }

    func testAllYinIsKun() {
        let info = KingWenTable.info(forBits: bits([false, false, false, false, false, false]))
        XCTAssertEqual(info.number, 2)
        XCTAssertEqual(info.name, "坤")
    }

    func testTaiIsLowerHeavenUpperEarth() {
        // 地天泰: bottom trigram all yang, top all yin.
        let info = KingWenTable.info(forBits: bits([true, true, true, false, false, false]))
        XCTAssertEqual(info.number, 11)
        XCTAssertEqual(info.name, "泰")
    }

    func testPiIsLowerEarthUpperHeaven() {
        let info = KingWenTable.info(forBits: bits([false, false, false, true, true, true]))
        XCTAssertEqual(info.number, 12)
        XCTAssertEqual(info.name, "否")
    }

    func testJiJiAlternatesFromYang() {
        // 既济 63: yang,yin,yang,yin,yang,yin (bottom→top).
        let info = KingWenTable.info(forBits: bits([true, false, true, false, true, false]))
        XCTAssertEqual(info.number, 63)
        XCTAssertEqual(info.name, "既济")
    }

    func testTableIsPermutationOf1to64() {
        let numbers = (0...63).map { KingWenTable.info(forBits: $0).number }.sorted()
        XCTAssertEqual(numbers, Array(1...64))
    }

    func testNamesAreDistinct() {
        let names = Set((0...63).map { KingWenTable.info(forBits: $0).name })
        XCTAssertEqual(names.count, 64)
    }
}
