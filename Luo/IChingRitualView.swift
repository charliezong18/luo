import SwiftUI
import SceneKit

/// 六爻 三钱法 Ritual screen. Scene (3 coins) fills the top; the cast Yao stack
/// grows bottom-up as each Throw settles; one cinnabar 掷 button advances. On the
/// 6th Yao the 本卦 (卦号 + 卦名 + 6-Yao glyph, 动爻 marked) fades in. 再占 resets.
struct IChingRitualView: View {
    @StateObject private var vm = IChingRitualViewModel()
    @State private var showText = false

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            SceneView(scene: vm.scene.scene, options: [], delegate: vm.scene)
                .ignoresSafeArea()

            VStack {
                hint
                if case .complete = vm.state {
                    EmptyView()
                } else {
                    tallyRow
                }
                Spacer()
                if case .complete(let hex) = vm.state {
                    hexagramResult(hex)
                }
                Spacer()
                castButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 20)
        }
        .animation(.easeInOut(duration: 0.35), value: vm.state)
        .animation(.easeInOut(duration: 0.35), value: vm.castYao.count)
        .onAppear { vm.startMotion() }
        .onDisappear { vm.stopMotion() }
    }

    private var hint: some View {
        Text(hintText)
            .font(Theme.serif(17))
            .foregroundColor(Theme.ink.opacity(vm.castYao.isEmpty ? 0.6 : 0.3))
    }

    private var hintText: String {
        switch vm.state {
        case .complete: return " "
        default:        return vm.castYao.isEmpty ? "心中默念所问" : "第 \(vm.castYao.count + 1) 爻"
        }
    }

    /// In-progress tally: a compact horizontal row read left→right in cast order
    /// (throw 1 … throw 6), small and dim, sitting just under the hint at the top
    /// so it never overlaps the coins in the center. 动爻 tinted cinnabar.
    private var tallyRow: some View {
        HStack(spacing: 14) {
            ForEach(Array(vm.castYao.enumerated()), id: \.offset) { _, yao in
                Text(yao.glyph)
                    .font(Theme.serif(28))
                    .foregroundColor((yao.isChanging ? Theme.cinnabar : Theme.ink).opacity(0.7))
            }
        }
        .frame(height: 34)
        .padding(.top, 6)
    }

    /// Final-reveal Yao row (centered result), full-size with a 动爻 ring.
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

    private func hexagramResult(_ hex: Hexagram) -> some View {
        VStack(spacing: 16) {
            Text("第 \(hex.number) 卦")
                .font(Theme.serif(16))
                .foregroundColor(Theme.ink.opacity(0.6))

            // 本卦 → 变卦 side by side (arrow + 变卦 only when there are 动爻).
            HStack(alignment: .center, spacing: 18) {
                hexagramColumn(hex)
                if let resulting = hex.resultingHexagram {
                    Text("→")
                        .font(Theme.serif(30))
                        .foregroundColor(Theme.ink.opacity(0.5))
                    hexagramColumn(resulting)
                }
            }

            // 释文 toggle — only when the 本卦 has seeded canonical text.
            if ZhouYiCorpus.text(forNumber: hex.number) != nil {
                Button(action: { showText.toggle() }) {
                    Text(showText ? "释文 ▴" : "释文 ▾")
                        .font(Theme.serif(15))
                        .foregroundColor(Theme.cinnabar)
                }
                if showText { canonicalText(hex) }
            }
        }
        .transition(.opacity)
    }

    /// One hexagram column: 卦名 over its vertical 6-Yao glyph (top = Yao 6).
    /// 动爻 rings come for free from `yaoRow` (the 变卦's lines are non-changing).
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

    /// Canonical 周易 text (ADR-0004): 本卦卦辞 · 动爻辞 (or 用九/用六 when all 6
    /// change on 乾/坤) · 变卦卦辞. Classical text only, verbatim.
    @ViewBuilder private func canonicalText(_ hex: Hexagram) -> some View {
        if let t = ZhouYiCorpus.text(forNumber: hex.number) {
            VStack(alignment: .leading, spacing: 8) {
                Text(hex.name + "　" + t.guaCi)
                    .font(Theme.serif(16))
                    .foregroundColor(Theme.ink)
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
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
    }

    /// The 爻辞 lines to show for the 动爻 — or 用九/用六 when all 6 Yao change on
    /// 乾/坤. `yaoCi` entries are already full labeled lines.
    private func changingLines(_ hex: Hexagram, _ t: HexagramText) -> [String] {
        if hex.changingPositions.count == 6, let yong = t.yong { return [yong] }
        return hex.changingPositions.map { t.yaoCi[$0 - 1] }
    }

    private var castButton: some View {
        Button(action: buttonAction) {
            Text(buttonLabel)
                .font(Theme.serif(20, weight: .medium))
                .foregroundColor(Theme.deskBackground)
                .frame(width: 120, height: 52)
                .background(Theme.cinnabar)
                .clipShape(Capsule())
                .opacity(vm.state == .casting ? 0.4 : 1)
        }
        .disabled(vm.state == .casting)
    }

    private var buttonLabel: String {
        if vm.isComplete { return "再占" }
        return "掷"
    }

    private func buttonAction() {
        if vm.isComplete { vm.reset() } else { vm.cast() }
    }
}

#Preview {
    IChingRitualView()
}
