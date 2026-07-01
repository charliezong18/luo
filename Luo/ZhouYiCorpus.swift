import Foundation

/// One hexagram's canonical 周易 text (ADR-0004): 卦辞 + 6 爻辞 (bottom→top, each
/// a full labeled line) + optional 用九/用六 (乾/坤 only). Displayed verbatim,
/// classical Chinese — never translated or glossed.
struct HexagramText {
    let guaCi: String
    let yaoCi: [String]   // exactly 6, index 0 = 初 (bottom)
    let yong: String?     // 用九 (乾) / 用六 (坤), else nil
}

/// Lookup of 周易 canonical text by King Wen number. SEED corpus (乾 + 坤) for
/// Sub-project ②; the full 64 卦辞 + 384 爻辞 backfill is a later data task that
/// only adds entries to `seed` — no logic change.
enum ZhouYiCorpus {
    static func text(forNumber n: Int) -> HexagramText? { seed[n] }

    private static let seed: [Int: HexagramText] = [
        1: HexagramText(
            guaCi: "元亨利貞",
            yaoCi: [
                "初九：潛龍勿用。",
                "九二：見龍在田，利見大人。",
                "九三：君子終日乾乾，夕惕若厲，无咎。",
                "九四：或躍在淵，无咎。",
                "九五：飛龍在天，利見大人。",
                "上九：亢龍有悔。",
            ],
            yong: "用九：見群龍无首，吉。"
        ),
        2: HexagramText(
            guaCi: "元亨，利牝馬之貞。君子有攸往，先迷後得主，利。西南得朋，東北喪朋。安貞吉。",
            yaoCi: [
                "初六：履霜，堅冰至。",
                "六二：直方大，不習无不利。",
                "六三：含章可貞，或從王事，无成有終。",
                "六四：括囊，无咎无譽。",
                "六五：黃裳，元吉。",
                "上六：龍戰于野，其血玄黃。",
            ],
            yong: "用六：利永貞。"
        ),
    ]
}
