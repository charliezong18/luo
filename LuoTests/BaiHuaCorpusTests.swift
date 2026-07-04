import XCTest
@testable import Luo

final class BaiHuaCorpusTests: XCTestCase {
    /// Skips (rather than fails) when the corpus is absent — clones without
    /// `BaiHua.key` run in the supported 原文-only degrade mode.
    func testEncryptedCorpusDecryptsComplete() throws {
        try XCTSkipIf(BaiHuaCorpus.gloss(forNumber: 1) == nil,
                      "BaiHua corpus unavailable (no key) — 原文-only mode")
        for n in 1...64 {
            let g = BaiHuaCorpus.gloss(forNumber: n)
            XCTAssertNotNil(g, "卦 \(n): gloss missing")
            XCTAssertEqual(g?.yaoCi.count, 6, "卦 \(n): expected 6 爻辞 glosses")
            XCTAssertFalse(g?.guaCi.isEmpty ?? true, "卦 \(n): empty 卦辞 gloss")
        }
        XCTAssertNotNil(BaiHuaCorpus.gloss(forNumber: 1)?.yong, "乾 missing 用九")
        XCTAssertNotNil(BaiHuaCorpus.gloss(forNumber: 2)?.yong, "坤 missing 用六")
        XCTAssertNil(BaiHuaCorpus.gloss(forNumber: 65))
    }
}
