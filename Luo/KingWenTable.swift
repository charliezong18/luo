import Foundation

/// One of the 8 trigrams (bagua). `bits` encodes its 3 lines bottom→top,
/// yang = 1 (bit 0 = bottom line).
enum Trigram: CaseIterable {
    case qian, dui, li, zhen, xun, kan, gen, kun

    var name: String {
        switch self {
        case .qian: return "乾"
        case .dui:  return "兑"
        case .li:   return "离"
        case .zhen: return "震"
        case .xun:  return "巽"
        case .kan:  return "坎"
        case .gen:  return "艮"
        case .kun:  return "坤"
        }
    }

    /// 乾兑离震巽坎艮坤 — the row/column order of every printed 六十四卦 lookup
    /// table (先天八卦次序). Same as declaration order.
    static let tableOrder: [Trigram] = allCases

    var bits: Int {
        switch self {
        case .qian: return 0b111  // 乾 ☰
        case .dui:  return 0b011  // 兑 ☱  (yang, yang, yin)
        case .li:   return 0b101  // 离 ☲  (yang, yin, yang)
        case .zhen: return 0b001  // 震 ☳  (yang, yin, yin)
        case .xun:  return 0b110  // 巽 ☴  (yin, yang, yang)
        case .kan:  return 0b010  // 坎 ☵  (yin, yang, yin)
        case .gen:  return 0b100  // 艮 ☶  (yin, yin, yang)
        case .kun:  return 0b000  // 坤 ☷
        }
    }
}

struct HexagramInfo: Equatable {
    let number: Int
    let name: String
}

/// Maps a 6-bit hexagram key (bottom→top, yang = 1) to its King Wen number +
/// 卦名. Built once from the King Wen-ordered entry list; the 6-bit key of each
/// entry is (lower.bits | upper.bits << 3).
enum KingWenTable {

    /// (King Wen number, 卦名, lower trigram, upper trigram), in King Wen order.
    private static let entries: [(Int, String, Trigram, Trigram)] = [
        (1,  "乾",   .qian, .qian),
        (2,  "坤",   .kun,  .kun),
        (3,  "屯",   .zhen, .kan),
        (4,  "蒙",   .kan,  .gen),
        (5,  "需",   .qian, .kan),
        (6,  "讼",   .kan,  .qian),
        (7,  "师",   .kan,  .kun),
        (8,  "比",   .kun,  .kan),
        (9,  "小畜", .qian, .xun),
        (10, "履",   .dui,  .qian),
        (11, "泰",   .qian, .kun),
        (12, "否",   .kun,  .qian),
        (13, "同人", .li,   .qian),
        (14, "大有", .qian, .li),
        (15, "谦",   .gen,  .kun),
        (16, "豫",   .kun,  .zhen),
        (17, "随",   .zhen, .dui),
        (18, "蛊",   .xun,  .gen),
        (19, "临",   .dui,  .kun),
        (20, "观",   .kun,  .xun),
        (21, "噬嗑", .zhen, .li),
        (22, "贲",   .li,   .gen),
        (23, "剥",   .kun,  .gen),
        (24, "复",   .zhen, .kun),
        (25, "无妄", .zhen, .qian),
        (26, "大畜", .qian, .gen),
        (27, "颐",   .zhen, .gen),
        (28, "大过", .xun,  .dui),
        (29, "坎",   .kan,  .kan),
        (30, "离",   .li,   .li),
        (31, "咸",   .gen,  .dui),
        (32, "恒",   .xun,  .zhen),
        (33, "遁",   .gen,  .qian),
        (34, "大壮", .qian, .zhen),
        (35, "晋",   .kun,  .li),
        (36, "明夷", .li,   .kun),
        (37, "家人", .li,   .xun),
        (38, "睽",   .dui,  .li),
        (39, "蹇",   .gen,  .kan),
        (40, "解",   .kan,  .zhen),
        (41, "损",   .dui,  .gen),
        (42, "益",   .zhen, .xun),
        (43, "夬",   .qian, .dui),
        (44, "姤",   .xun,  .qian),
        (45, "萃",   .kun,  .dui),
        (46, "升",   .xun,  .kun),
        (47, "困",   .kan,  .dui),
        (48, "井",   .xun,  .kan),
        (49, "革",   .li,   .dui),
        (50, "鼎",   .xun,  .li),
        (51, "震",   .zhen, .zhen),
        (52, "艮",   .gen,  .gen),
        (53, "渐",   .gen,  .xun),
        (54, "归妹", .dui,  .zhen),
        (55, "丰",   .li,   .zhen),
        (56, "旅",   .gen,  .li),
        (57, "巽",   .xun,  .xun),
        (58, "兑",   .dui,  .dui),
        (59, "涣",   .kan,  .xun),
        (60, "节",   .dui,  .kan),
        (61, "中孚", .dui,  .xun),
        (62, "小过", .gen,  .zhen),
        (63, "既济", .li,   .kan),
        (64, "未济", .kan,  .li),
    ]

    private static let byBits: [Int: HexagramInfo] = {
        var map: [Int: HexagramInfo] = [:]
        for (number, name, lower, upper) in entries {
            let key = lower.bits | (upper.bits << 3)
            map[key] = HexagramInfo(number: number, name: name)
        }
        return map
    }()

    /// Look up the hexagram for a 6-bit key (0…63). The map is total over 0…63.
    static func info(forBits bits: Int) -> HexagramInfo {
        byBits[bits]!
    }

    /// All 64 hexagrams in King Wen order, carrying the 6-bit key so a browser
    /// can draw the lines without casting. Used by the 读经 library.
    static let allInKingWenOrder: [(number: Int, name: String, bits: Int)] =
        entries.map { (number: $0.0, name: $0.1, bits: $0.2.bits | ($0.3.bits << 3)) }
}
