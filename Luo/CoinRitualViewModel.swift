import SwiftUI
import SceneKit

/// Ritual semantics for a single coin. Heads → 阳, tails → 阴 (edge can't happen
/// on a flat tray; folded into 阳). Kept in the VM layer so PhysicsScene /
/// ThrowResult stay free of divination meaning.
enum Yinyang: Equatable {
    case yang, yin

    init(_ face: CoinFace) { self = (face == .tails) ? .yin : .yang }

    var glyph: String { self == .yang ? "阳" : "阴" }
    var reading: String { self == .yang ? "是" : "否" }
}

/// What the Coin Ritual screen is showing.
enum CoinCastState: Equatable {
    case idle                 // ready; hint + 掷
    case casting              // coin in flight; button disabled
    case result(Yinyang)      // settled; 阳/阴 revealed; button → 再掷
}

@MainActor
final class CoinRitualViewModel: ObservableObject {
    @Published private(set) var state: CoinCastState = .idle
    @Published private(set) var hasCast = false

    private let haptics = HapticsService()
    private let motion = MotionService()

    /// Lazy so the escaping callbacks can capture a fully-initialized self.
    lazy var scene: PhysicsScene = PhysicsScene(
        config: .v1,
        onSettle: { [weak self] results in self?.handleSettle(results) },
        onStateChange: { [weak self] s in self?.handleStateChange(s) }
    )

    /// Throw the coin (tap button or shake).
    func cast() {
        scene.performThrow()
        state = .casting
    }

    /// Start/stop device-shake casting (no-op in simulator). A shake runs the same
    /// full Throw as the button — reset + lift + random tumble torque — so a shaken
    /// cast is exactly as fair as a tapped one (a bare upward impulse barely flips
    /// the coin and biases the result). Ignored mid-flight.
    func startMotion() {
        motion.start { [weak self] _ in
            guard let self, self.state != .casting else { return }
            self.cast()
        }
    }
    func stopMotion() { motion.stop() }

    // MARK: - PhysicsScene callbacks

    private func handleSettle(_ results: [ThrowResult]) {
        guard let first = results.first else { return }
        haptics.playSettleThunk()
        state = .result(Yinyang(first.faceUp))
        hasCast = true
    }

    private func handleStateChange(_ s: SettleState) {
        // The settled face arrives via handleSettle; here we only keep `.casting`
        // alive while the coin is in motion. Ignore .idle/.settled.
        switch s {
        case .throwing, .settling:
            if state != .casting { state = .casting }
        case .idle, .settled:
            break
        }
    }
}
