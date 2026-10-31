import SwiftUI

/// Trigram / hexagram lines drawn as shapes rather than font glyphs, so they
/// scale cleanly from a 26-pt table cell to a 150-pt tap target. Yang = one
/// solid bar, yin = two short bars. `bits` reads bottom→top (bit 0 = bottom
/// line), the same convention as `Hexagram.presentBits` and `Trigram.bits`.
/// Lines whose bit is set in `changingMask` are drawn in cinnabar (动爻).
struct LinesGlyph: View {
    let bits: Int
    var lineCount: Int = 6
    var changingMask: Int = 0
    var width: CGFloat = 28
    var thickness: CGFloat = 2.5
    var spacing: CGFloat = 3
    var color: Color = Theme.ink

    var body: some View {
        VStack(spacing: spacing) {
            ForEach((0..<lineCount).reversed(), id: \.self) { i in
                line(isYang: bits & (1 << i) != 0,
                     tint: changingMask & (1 << i) != 0 ? Theme.cinnabar : color)
            }
        }
        .frame(width: width)
    }

    @ViewBuilder private func line(isYang: Bool, tint: Color) -> some View {
        if isYang {
            Rectangle().fill(tint)
                .frame(width: width, height: thickness)
        } else {
            HStack(spacing: width * 0.22) {
                Rectangle().fill(tint)
                Rectangle().fill(tint)
            }
            .frame(width: width, height: thickness)
        }
    }
}
