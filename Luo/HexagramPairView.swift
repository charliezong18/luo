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
                ForEach(changingLines(hex, t), id: \.self) { line in
                    Text(line)
                        .font(Theme.serif(15))
                        .foregroundColor(Theme.ink.opacity(0.85))
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

    private func changingLines(_ hex: Hexagram, _ t: HexagramText) -> [String] {
        if hex.changingPositions.count == 6, let yong = t.yong { return [yong] }
        return hex.changingPositions.map { t.yaoCi[$0 - 1] }
    }
}
