import XCTest
@testable import Luo

/// The 读经 library is a pure lookup over the King Wen table + corpus. These
/// pin the two things a browser can silently get wrong: a missing hexagram, and
/// a row whose bits draw a different hexagram than its number claims.
final class SutraLibraryTests: XCTestCase {

    func testAll64PresentInKingWenOrder() {
        let all = KingWenTable.allInKingWenOrder
        XCTAssertEqual(all.count, 64)
        XCTAssertEqual(all.map(\.number), Array(1...64))
    }

    func testBitsRoundTripToTheSameHexagram() {
        for entry in KingWenTable.allInKingWenOrder {
            let info = KingWenTable.info(forBits: entry.bits)
            XCTAssertEqual(info.number, entry.number, "bits for #\(entry.number) drew #\(info.number)")
            XCTAssertEqual(info.name, entry.name)
        }
    }

    func testEveryEntryReconstructsAStaticHexagramWithSixLines() {
        for entry in KingWenTable.allInKingWenOrder {
            let hex = Hexagram(presentBits: entry.bits, changingMask: 0)
            XCTAssertEqual(hex.number, entry.number)
            XCTAssertEqual(hex.yao.count, 6)
            XCTAssertTrue(hex.changingPositions.isEmpty, "#\(entry.number) should be static when browsed")
        }
    }

    func testEveryHexagramHasCanonicalTextToRead() {
        for entry in KingWenTable.allInKingWenOrder {
            let t = ZhouYiCorpus.text(forNumber: entry.number)
            XCTAssertNotNil(t, "#\(entry.number) \(entry.name) has no text to read")
            XCTAssertFalse(t?.guaCi.isEmpty ?? true)
            XCTAssertEqual(t?.yaoCi.count, 6)
        }
    }
}
