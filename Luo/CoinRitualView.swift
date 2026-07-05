import SwiftUI
import SceneKit

/// 落 — Coin Ritual MVP screen. The PhysicsScene fills the screen; a quiet hint,
/// a single cinnabar cast button, and a fade-in 阳/阴 result overlay it. A long
/// press opens the throwaway tuning Harness as a debug sheet.
struct CoinRitualView: View {
    @StateObject private var vm = CoinRitualViewModel()
    @State private var showDebug = false

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()

            // Fixed-framing scene (no camera control in the ritual).
            // .rendersContinuously: SceneKit physics steps with the render loop;
            // a paused loop swallows shake impulses until a tap wakes the view.
            SceneView(scene: vm.scene.scene, options: [.rendersContinuously], delegate: vm.scene)
                .ignoresSafeArea()

            VStack {
                hint
                Spacer()
                resultOverlay
                Spacer()
                castButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 20)
        }
        .animation(.easeInOut(duration: 0.35), value: vm.state)
        .onAppear { vm.startMotion() }
        .onDisappear { vm.stopMotion() }
        // Long-press anywhere opens the hidden tuning Harness.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.5).onEnded { _ in showDebug = true }
        )
        .sheet(isPresented: $showDebug) { HarnessView() }
    }

    private var hint: some View {
        Text("心中默念所问")
            .font(Theme.serif(17))
            .foregroundColor(Theme.ink.opacity(vm.hasCast ? 0.25 : 0.6))
    }

    @ViewBuilder private var resultOverlay: some View {
        if case .result(let yy) = vm.state {
            VStack(spacing: 10) {
                Text(yy.glyph)
                    .font(Theme.serif(96, weight: .medium))
                    .foregroundColor(Theme.ink)
                Text(yy.reading)
                    .font(Theme.serif(22))
                    .foregroundColor(Theme.ink.opacity(0.7))
            }
            .transition(.opacity)
        }
    }

    private var castButton: some View {
        Button(action: { vm.cast() }) {
            Text(vm.hasCast ? "再掷" : "掷")
                .font(Theme.serif(20, weight: .medium))
                .foregroundColor(Theme.deskBackground)
                .frame(width: 120, height: 52)
                .background(Theme.cinnabar)
                .clipShape(Capsule())
                .opacity(vm.state == .casting ? 0.4 : 1)
        }
        .disabled(vm.state == .casting)
    }
}

#Preview {
    CoinRitualView()
}
