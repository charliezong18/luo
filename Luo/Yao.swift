import Foundation

/// One of the 6 lines in a Hexagram, produced by one Throw of 3 coins.
/// Heads = 背 = 阳 (per CONTEXT.md 三钱法). Old (changing) Yao come from a
/// unanimous Throw (3 heads or 3 tails); young Yao from a 2:1 split.
enum YaoKind: Equatable {
    case oldYin      // 0 heads — yin, changing
    case youngYang   // 1 head  — yang
    case youngYin    // 2 heads — yin
    case oldYang     // 3 heads — yang, changing
}

struct Yao: Equatable {
    let kind: YaoKind

    init(faces: [CoinFace]) {
        let heads = faces.filter { $0 == .heads }.count
        switch heads {
        case 3:  kind = .oldYang
        case 2:  kind = .youngYin
        case 1:  kind = .youngYang
        default: kind = .oldYin   // 0 heads
        }
    }

    var isYang: Bool { kind == .oldYang || kind == .youngYang }
    var isChanging: Bool { kind == .oldYang || kind == .oldYin }

    /// Solid ⚊ (yang) or broken ⚋ (yin).
    var glyph: String { isYang ? "⚊" : "⚋" }
}
