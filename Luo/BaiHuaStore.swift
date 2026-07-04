import Foundation
import CryptoKit

/// Plain-language (白话) gloss layer over the canonical 周易 text. Kept SEPARATE
/// from `ZhouYiCorpus` so the canonical text stays verbatim (ADR-0004) — this is
/// an added reading aid, never a replacement of the original.
///
/// The corpus itself is proprietary and ships only as an encrypted bundle
/// resource (`BaiHua.enc`, sealed by `scripts/baihua-crypt.swift`). The key
/// (`BaiHua.key`) is not in the repo: builds without it still compile and run,
/// degrading to showing the 原文 alone.
struct HexagramGloss {
    let guaCi: String
    let yaoCi: [String]   // 6 lines, index 0 = 初 (bottom); empty ⇒ 原文-only
    let yong: String?

    /// 卦辞 gloss required; 爻辞/用 optional so a partial entry still works.
    init(_ guaCi: String, yaoCi: [String] = [], yong: String? = nil) {
        self.guaCi = guaCi
        self.yaoCi = yaoCi
        self.yong = yong
    }
}

enum BaiHuaCorpus {
    static func gloss(forNumber n: Int) -> HexagramGloss? { store[n] }
    /// The 卦辞 plain-language gloss, or nil if not available.
    static func guaCi(forNumber n: Int) -> String? { store[n]?.guaCi }

    private static let store: [Int: HexagramGloss] = decryptStore()

    private static func decryptStore() -> [Int: HexagramGloss] {
        let bundle = Bundle(for: BundleToken.self)
        guard let keyURL = bundle.url(forResource: "BaiHua", withExtension: "key"),
              let encURL = bundle.url(forResource: "BaiHua", withExtension: "enc"),
              let keyB64 = try? String(contentsOf: keyURL, encoding: .utf8)
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              let keyData = Data(base64Encoded: keyB64),
              let blob = try? Data(contentsOf: encURL),
              let box = try? AES.GCM.SealedBox(combined: blob),
              let json = try? AES.GCM.open(box, using: SymmetricKey(data: keyData)),
              let obj = (try? JSONSerialization.jsonObject(with: json)) as? [String: [String: Any]]
        else { return [:] }

        var out: [Int: HexagramGloss] = [:]
        for (k, v) in obj {
            guard let n = Int(k), let guaCi = v["g"] as? String else { continue }
            out[n] = HexagramGloss(guaCi,
                                   yaoCi: v["y"] as? [String] ?? [],
                                   yong: v["yong"] as? String)
        }
        return out
    }
}

private final class BundleToken {}
