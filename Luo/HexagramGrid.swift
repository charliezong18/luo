import SwiftUI

/// The printed 查卦表: eight upper trigrams across the top, eight lower
/// trigrams down the side, each cell the hexagram they form. Someone who has
/// just thrown three coins six times reads the bottom three lines off the left
/// edge and the top three off the top edge and lands on the cell — no need to
/// scan 64 names. Pure data here so the layout is unit-testable.
enum HexagramGrid {
    struct Cell: Equatable {
        let upper: Trigram
        let lower: Trigram
        let number: Int
        let name: String
        let bits: Int
    }

    /// 乾兑离震巽坎艮坤 — the order every printed table uses.
    static let trigrams = Trigram.tableOrder

    /// `rows[r][c]`: row r = lower trigram `trigrams[r]`, column c = upper
    /// trigram `trigrams[c]`. The upper trigram is the top half of each glyph,
    /// so each column header is literally the top of every glyph below it.
    static let rows: [[Cell]] = trigrams.map { lower in
        trigrams.map { upper in
            let bits = lower.bits | (upper.bits << 3)
            let info = KingWenTable.info(forBits: bits)
            return Cell(upper: upper, lower: lower, number: info.number, name: info.name, bits: bits)
        }
    }
}

/// 卦象 view of the 读经 library: the 8×8 table above, every cell a push to the
/// same detail page the 名称 list uses.
struct HexagramGridView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)
    private let cellHeight: CGFloat = 60

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                LazyVGrid(columns: columns, spacing: 0) {
                    corner
                    ForEach(HexagramGrid.trigrams, id: \.self) { trigramHeader($0) }
                    ForEach(Array(HexagramGrid.rows.enumerated()), id: \.offset) { r, row in
                        trigramHeader(HexagramGrid.trigrams[r])
                        ForEach(row, id: \.number) { cell($0) }
                    }
                }
                .padding(.horizontal, 8)
                Text("横看上卦，竖看下卦；点任一卦读经文。")
                    .font(Theme.serif(12))
                    .foregroundColor(Theme.ink.opacity(0.45))
            }
            .padding(.vertical, 12)
        }
    }

    private var corner: some View {
        VStack(spacing: 3) {
            Text("上卦→")
            Text("下卦↓")
        }
        .font(Theme.serif(9))
        .foregroundColor(Theme.ink.opacity(0.45))
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 0.5))
    }

    private func trigramHeader(_ t: Trigram) -> some View {
        VStack(spacing: 3) {
            LinesGlyph(bits: t.bits, lineCount: 3, width: 18, thickness: 2, spacing: 2.4,
                       color: Theme.ink.opacity(0.75))
            Text(t.name)
                .font(Theme.serif(10))
                .foregroundColor(Theme.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 0.5))
    }

    private func cell(_ c: HexagramGrid.Cell) -> some View {
        NavigationLink(value: c.number) {
            VStack(spacing: 3) {
                LinesGlyph(bits: c.bits, width: 26, thickness: 2.2, spacing: 2.6)
                Text(c.name)
                    .font(Theme.serif(10, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(c.number)")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.ink.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .contentShape(Rectangle())
            .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("grid.\(c.number)")
        .accessibilityLabel("\(c.name) 第\(c.number)卦")
    }
}
