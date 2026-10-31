import SwiftUI

/// One hexagram, read rather than cast: the lines, then 卦辞 and all six 爻辞
/// verbatim (ADR-0004), each with its 白话 gloss underneath when one exists.
struct SutraDetailView: View {
    let number: Int

    private var hexagram: Hexagram? {
        KingWenTable.allInKingWenOrder.first { $0.number == number }
            .map { Hexagram(presentBits: $0.bits, changingMask: 0) }
    }

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let hex = hexagram { header(hex) }
                    if let t = ZhouYiCorpus.text(forNumber: number) {
                        let gloss = BaiHuaCorpus.gloss(forNumber: number)
                        passage(t.guaCi, gloss?.guaCi, size: 17)
                        ForEach(0..<t.yaoCi.count, id: \.self) { i in
                            passage(t.yaoCi[i], gloss?.yaoCi.indices.contains(i) == true
                                                ? gloss?.yaoCi[i] : nil, size: 16)
                        }
                        if let yong = t.yong {
                            passage(yong, gloss?.yong, size: 16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("第 \(number) 卦")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Name, the six lines drawn as real bars (the same glyph the 卦象 table
    /// uses, so what you tapped is what you see), and the 上/下卦 that make it —
    /// the two coordinates for finding this hexagram in a printed table.
    private func header(_ hex: Hexagram) -> some View {
        VStack(spacing: 12) {
            Text(hex.name)
                .font(Theme.serif(34, weight: .medium))
                .foregroundColor(Theme.ink)
            LinesGlyph(bits: hex.presentBits, width: 72, thickness: 6, spacing: 9)
            if let upper = trigram(hex.presentBits >> 3), let lower = trigram(hex.presentBits & 0b111) {
                Text("上\(upper.name)　下\(lower.name)")
                    .font(Theme.serif(13))
                    .foregroundColor(Theme.ink.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private func trigram(_ bits: Int) -> Trigram? {
        Trigram.allCases.first { $0.bits == bits }
    }

    /// 原文 on top, 白话 indented and dimmed beneath — the same two-layer
    /// treatment the Cast result uses, so the reading layers stay consistent.
    @ViewBuilder private func passage(_ text: String, _ baihua: String?, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(text)
                .font(Theme.serif(size))
                .foregroundColor(Theme.ink.opacity(0.92))
            if let bh = baihua {
                Text("白话　" + bh)
                    .font(Theme.serif(size - 2))
                    .foregroundColor(Theme.ink.opacity(0.55))
                    .padding(.leading, 12)
            }
        }
    }
}
