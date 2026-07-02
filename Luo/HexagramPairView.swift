import SwiftUI

/// Shared rendering of a completed 六爻 result: 第 N 卦 header, 本卦 → 变卦 columns
/// (动爻 marked with cinnabar rings), and the 释文 canonical-text toggle. Used by
/// both the ritual result screen and the Cast Log detail. `showText` is owned by
/// the host so each screen keeps its own expand/collapse state.
struct HexagramPairView: View {
    let hexagram: Hexagram
    @Binding var showText: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("第 \(hexagram.number) 卦")
                .font(Theme.serif(16))
                .foregroundColor(Theme.ink.opacity(0.6))

            HStack(alignment: .center, spacing: 18) {
                hexagramColumn(hexagram)
                if let resulting = hexagram.resultingHexagram {
                    Text("→")
                        .font(Theme.serif(30))
                        .foregroundColor(Theme.ink.opacity(0.5))
                    hexagramColumn(resulting)
                }
            }

            if ZhouYiCorpus.text(forNumber: hexagram.number) != nil {
                Button(action: { showText.toggle() }) {
                    Text(showText ? "释文 ▴" : "释文 ▾")
                        .font(Theme.serif(15))
                        .foregroundColor(Theme.cinnabar)
                }
                if showText { canonicalText(hexagram) }
            }
        }
    }

    private func yaoRow(_ yao: Yao) -> some View {
        HStack(spacing: 10) {
            Text(yao.glyph)
                .font(Theme.serif(30))
                .foregroundColor(Theme.ink)
            if yao.isChanging {
                Circle().stroke(Theme.cinnabar, lineWidth: 1.5).frame(width: 8, height: 8)
            }
        }
    }

    private func hexagramColumn(_ hex: Hexagram) -> some View {
        VStack(spacing: 8) {
            Text(hex.name)
                .font(Theme.serif(30, weight: .medium))
                .foregroundColor(Theme.ink)
            VStack(spacing: 5) {
                ForEach(Array(hex.yao.enumerated().reversed()), id: \.offset) { _, yao in
                    yaoRow(yao)
                }
            }
        }
    }

    @ViewBuilder private func canonicalText(_ hex: Hexagram) -> some View {
        if let t = ZhouYiCorpus.text(forNumber: hex.number) {
            VStack(alignment: .leading, spacing: 8) {
                Text(hex.name + "　" + t.guaCi)
                    .font(Theme.serif(16))
                    .foregroundColor(Theme.ink)
                baiHuaLine(hex.number)
                ForEach(Array(changingLines(hex, t).enumerated()), id: \.offset) { _, line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.text)
                            .font(Theme.serif(15))
                            .foregroundColor(Theme.ink.opacity(0.85))
                        if let bh = line.baihua {
                            Text("白话　" + bh)
                                .font(Theme.serif(14))
                                .foregroundColor(Theme.ink.opacity(0.55))
                                .padding(.leading, 12)
                        }
                    }
                }
                if let resulting = hex.resultingHexagram {
                    let rt = ZhouYiCorpus.text(forNumber: resulting.number)?.guaCi ?? "（待补）"
                    Text("变卦 " + resulting.name + "　" + rt)
                        .font(Theme.serif(16))
                        .foregroundColor(Theme.ink.opacity(0.9))
                    baiHuaLine(resulting.number)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
    }

    /// The 白话 gloss for a hexagram's 卦辞, indented and dimmed so it reads as an
    /// aid under the 原文. Absent glosses render nothing (graceful degrade).
    @ViewBuilder private func baiHuaLine(_ number: Int) -> some View {
        if let bh = BaiHuaCorpus.guaCi(forNumber: number) {
            Text("白话　" + bh)
                .font(Theme.serif(14))
                .foregroundColor(Theme.ink.opacity(0.55))
                .padding(.leading, 12)
        }
    }

    /// Each changing line as (原文, 白话?). When all 6 lines change, 乾/坤 read
    /// their 用九/用六 instead of the six 爻辞. 白话 degrades to nil when unwritten.
    private func changingLines(_ hex: Hexagram, _ t: HexagramText) -> [(text: String, baihua: String?)] {
        let gloss = BaiHuaCorpus.gloss(forNumber: hex.number)
        if hex.changingPositions.count == 6, let yong = t.yong {
            return [(yong, gloss?.yong)]
        }
        return hex.changingPositions.map { pos in
            let bh = gloss?.yaoCi.indices.contains(pos - 1) == true ? gloss?.yaoCi[pos - 1] : nil
            return (t.yaoCi[pos - 1], bh)
        }
    }
}
