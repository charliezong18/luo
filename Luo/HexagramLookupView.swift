import SwiftUI

/// Six hand-entered lines, bottom→top (index 0 = 初爻) — e.g. read off three
/// coins thrown six times away from the app. A plain value so the mapping to
/// 本卦 / 变卦 is unit-testable without the view.
struct HexagramInput: Equatable {
    var isYang: [Bool]
    var isChanging: [Bool]

    /// Blank slate: 乾, all six lines static. Tapping breaks lines from there.
    static let empty = HexagramInput(presentBits: 0b111111, changingMask: 0)

    init(presentBits: Int, changingMask: Int) {
        isYang = (0..<6).map { presentBits & (1 << $0) != 0 }
        isChanging = (0..<6).map { changingMask & (1 << $0) != 0 }
    }

    var hexagram: Hexagram {
        Hexagram(yao: (0..<6).map { Yao(isYang: isYang[$0], isChanging: isChanging[$0]) })
    }

    mutating func togglePolarity(_ i: Int) { isYang[i].toggle() }
    mutating func toggleChanging(_ i: Int) { isChanging[i].toggle() }
}

/// 按卦象查: enter six lines by hand, see the 本卦 (and 变卦 when any line is
/// marked 动) update live, then read either one. Built for the person with
/// real coins on the table who wants the text for what they just threw.
struct HexagramLookupView: View {
    @State private var input = HexagramInput.empty
    @State private var showText = false

    private static let positionNames = ["初", "二", "三", "四", "五", "上"]

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Text("三枚硬币掷一次定一爻，自下而上记六爻。\n点爻线换阴阳，点「动」标动爻。")
                        .font(Theme.serif(13))
                        .foregroundColor(Theme.ink.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    VStack(spacing: 8) {
                        ForEach((0..<6).reversed(), id: \.self) { lineRow($0) }
                    }
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                        .padding(.vertical, 4)
                    HexagramPairView(hexagram: input.hexagram, showText: $showText)
                    readButtons
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("按卦象查")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("清除") {
                    input = .empty
                    showText = false
                }
                .font(Theme.serif(16))
            }
        }
    }

    private func lineRow(_ i: Int) -> some View {
        HStack(spacing: 14) {
            Text(Self.positionNames[i] + "爻")
                .font(Theme.serif(13))
                .foregroundColor(Theme.ink.opacity(0.5))
                .frame(width: 36, alignment: .trailing)
            Button(action: { input.togglePolarity(i) }) {
                LinesGlyph(bits: input.isYang[i] ? 1 : 0, lineCount: 1,
                           changingMask: input.isChanging[i] ? 1 : 0,
                           width: 150, thickness: 8, spacing: 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("line.\(i + 1)")
            .accessibilityLabel("第\(i + 1)爻 \(input.isYang[i] ? "阳" : "阴")")
            Button(action: { input.toggleChanging(i) }) {
                Text("动")
                    .font(Theme.serif(14, weight: .medium))
                    .foregroundColor(input.isChanging[i] ? Theme.deskBackground : Theme.ink.opacity(0.6))
                    .frame(width: 44, height: 32)
                    .background(input.isChanging[i] ? Theme.cinnabar : Theme.surfaceRaised, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("changing.\(i + 1)")
            .accessibilityLabel(input.isChanging[i] ? "第\(i + 1)爻 动爻，点按取消" : "第\(i + 1)爻 标为动爻")
        }
    }

    @ViewBuilder private var readButtons: some View {
        let hex = input.hexagram
        HStack(spacing: 12) {
            NavigationLink(value: hex.number) { readLabel("读本卦 " + hex.name) }
            if let resulting = hex.resultingHexagram {
                NavigationLink(value: resulting.number) { readLabel("读变卦 " + resulting.name) }
            }
        }
        .padding(.top, 4)
    }

    private func readLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.serif(16))
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
    }
}
