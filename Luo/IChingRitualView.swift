import SwiftUI
import SceneKit
import SwiftData

/// 六爻 三钱法 Ritual screen. Scene (3 coins) fills the top; the cast Yao stack
/// grows bottom-up as each Throw settles; one cinnabar 掷 button advances. On the
/// 6th Yao the 本卦 (卦号 + 卦名 + 6-Yao glyph, 动爻 marked) fades in. 再占 resets.
struct IChingRitualView: View {
    @StateObject private var vm = IChingRitualViewModel()
    @State private var showText = false
    @Environment(\.modelContext) private var modelContext

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
        .onChange(of: vm.state) { _, newState in
            if case .complete(let hex) = newState {
                modelContext.insert(CastRecord(from: hex, at: Date()))
            }
        }
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

    private func hexagramResult(_ hex: Hexagram) -> some View {
        HexagramPairView(hexagram: hex, showText: $showText)
            .transition(.opacity)
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
