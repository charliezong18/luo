import SwiftUI
import SceneKit

/// 六爻 三钱法 Ritual screen. Scene (3 coins) fills the top; the cast Yao stack
/// grows bottom-up as each Throw settles; one cinnabar 掷 button advances. On the
/// 6th Yao the 本卦 (卦号 + 卦名 + 6-Yao glyph, 动爻 marked) fades in. 再占 resets.
struct IChingRitualView: View {
    @StateObject private var vm = IChingRitualViewModel()

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            SceneView(scene: vm.scene.scene, options: [], delegate: vm.scene)
                .ignoresSafeArea()

            VStack {
                hint
                Spacer()
                if case .complete(let hex) = vm.state {
                    hexagramResult(hex)
                } else {
                    yaoStack
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

    /// Cast Yao so far, bottom-up (newest on top of the stack visually = top row
    /// is the highest Yao index; we render top→bottom = Yao 6→1).
    private var yaoStack: some View {
        VStack(spacing: 8) {
            ForEach(Array(vm.castYao.enumerated().reversed()), id: \.offset) { _, yao in
                yaoRow(yao)
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

    private func hexagramResult(_ hex: Hexagram) -> some View {
        VStack(spacing: 14) {
            Text("第 \(hex.number) 卦")
                .font(Theme.serif(16))
                .foregroundColor(Theme.ink.opacity(0.6))
            Text(hex.name)
                .font(Theme.serif(72, weight: .medium))
                .foregroundColor(Theme.ink)
            VStack(spacing: 6) {
                ForEach(Array(hex.yao.enumerated().reversed()), id: \.offset) { _, yao in
                    yaoRow(yao)
                }
            }
            .padding(.top, 6)
        }
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
