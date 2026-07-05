import SwiftUI
import SceneKit

/// Phase 1 Coin Harness UI — intentionally ugly per ADR-0007.
/// Top: live SceneView with the single coin.
/// Middle: Settle indicator + Throw / Reset / Shake-toggle controls.
/// Bottom: scroll list of physics-parameter sliders.
struct HarnessView: View {
    @StateObject private var params = PhysicsParams()
    @StateObject private var motion = MotionService()
    @State private var settleState: SettleState = .idle
    @State private var scene: PhysicsScene?
    private let haptics = HapticsService()

    var body: some View {
        VStack(spacing: 0) {
            sceneArea
            statusBar
            controlRow
            Divider()
            slidersList
        }
        .onAppear { ensureScene() }
        .onChange(of: params.coinMass) { _, _ in scene?.apply(params.makeConfig()) }
        .onChange(of: params.coinRadius) { _, _ in scene?.apply(params.makeConfig()) }
        .onChange(of: params.coinThickness) { _, _ in scene?.apply(params.makeConfig()) }
        .onChange(of: params.gravity) { _, _ in scene?.apply(params.makeConfig()) }
        .onChange(of: params.restitution) { _, _ in scene?.apply(params.makeConfig()) }
        .onChange(of: params.friction) { _, _ in scene?.apply(params.makeConfig()) }
        .onChange(of: params.rollingFriction) { _, _ in scene?.apply(params.makeConfig()) }
        .onChange(of: params.linearDamping) { _, _ in scene?.apply(params.makeConfig()) }
        .onChange(of: params.angularDamping) { _, _ in scene?.apply(params.makeConfig()) }
    }

    // MARK: - Sub-views

    private var sceneArea: some View {
        Group {
            if let scene {
                SceneView(
                    scene: scene.scene,
                    options: [.allowsCameraControl, .rendersContinuously],
                    delegate: scene
                )
            } else {
                Color.black.overlay(ProgressView().tint(.white))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(Color.black)
    }

    private var statusBar: some View {
        HStack {
            Text("State: \(settleState.label)").font(.system(.body, design: .monospaced))
            Spacer()
            if motion.isRunning {
                Text(String(format: "shake %.2fg", motion.lastShakeMagnitude))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Button("Throw") { scene?.performThrow() }
                .buttonStyle(.borderedProminent)
            Button("Reset") { scene?.reset() }
                .buttonStyle(.bordered)
            Toggle("Shake", isOn: shakeBinding)
                .toggleStyle(.button)
            Spacer()
            Button("Defaults") { params.resetToDefaults() }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var slidersList: some View {
        List {
            Section("Coin") {
                slider("mass (kg)", $params.coinMass, 0.001...0.05, format: "%.4f")
                slider("radius (m)", $params.coinRadius, 0.005...0.03, format: "%.4f")
                slider("thickness (m)", $params.coinThickness, 0.0005...0.005, format: "%.4f")
            }
            Section("World") {
                slider("gravity (m/s²)", $params.gravity, 1...20, format: "%.2f")
            }
            Section("Contact") {
                slider("restitution", $params.restitution, 0...1, format: "%.2f")
                slider("friction", $params.friction, 0...1, format: "%.2f")
                slider("rolling friction", $params.rollingFriction, 0...1, format: "%.2f")
            }
            Section("Damping") {
                slider("linear damping", $params.linearDamping, 0...1, format: "%.2f")
                slider("angular damping", $params.angularDamping, 0...1, format: "%.2f")
            }
            Section("Settle detector") {
                slider("lin threshold (m/s)", $params.settleLinearThreshold, 0.001...0.2, format: "%.3f")
                slider("ang threshold (rad/s)", $params.settleAngularThreshold, 0.1...4, format: "%.2f")
                slider("hold seconds", $params.settleHoldSeconds, 0.05...1.0, format: "%.2f")
            }
            Section("Throw") {
                slider("linear impulse", $params.throwLinearImpulse, 0.005...0.5, format: "%.3f")
                slider("angular impulse", $params.throwAngularImpulse, 0...0.12, format: "%.3f")
                slider("h jitter", $params.throwHorizontalJitter, 0...0.05, format: "%.3f")
            }
        }
        .listStyle(.plain)
    }

    private func slider(_ label: String,
                        _ value: Binding<Double>,
                        _ range: ClosedRange<Double>,
                        format: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(.caption, design: .monospaced))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Wiring

    private var shakeBinding: Binding<Bool> {
        Binding(
            get: { motion.isRunning },
            set: { wantsOn in
                if wantsOn {
                    motion.start { mag in
                        scene?.shakeImpulse(fraction: MotionService.impulseFraction(forMagnitude: mag))
                    }
                } else {
                    motion.stop()
                }
            }
        )
    }

    private func ensureScene() {
        guard scene == nil else { return }
        scene = PhysicsScene(
            config: params.makeConfig(),
            onSettle: { _ in haptics.playSettleThunk() },
            onStateChange: { newState in
                Task { @MainActor in settleState = newState }
            }
        )
    }
}

#Preview {
    HarnessView()
}
