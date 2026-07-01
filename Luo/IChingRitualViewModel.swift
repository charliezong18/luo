import SwiftUI
import SceneKit

/// What the 六爻 screen is showing.
enum IChingCastState: Equatable {
    case idle                 // ready for the next Throw (0…5 Yao cast)
    case casting              // coins in flight
    case complete(Hexagram)   // 6 Yao cast; 本卦 revealed
}

/// Drives the I Ching 六爻 三钱法 Ritual: 6 Throws of 3 coins, each aggregated
/// into one Yao bottom-up, into the Present Hexagram (本卦). Divination meaning
/// lives here; `PhysicsScene`/`ThrowResult` stay meaning-free.
@MainActor
final class IChingRitualViewModel: ObservableObject {
    @Published private(set) var state: IChingCastState = .idle
    @Published private(set) var castYao: [Yao] = []

    private let haptics = HapticsService()
    private let motion = MotionService()

    lazy var scene: PhysicsScene = PhysicsScene(
        config: .iChing,
        onSettle: { [weak self] results in self?.handleSettle(results) },
        onStateChange: { [weak self] s in self?.handleStateChange(s) }
    )

    var isComplete: Bool { if case .complete = state { return true }; return false }

    /// Throw the next Yao (tap or shake). No-op while casting or complete.
    func cast() {
        guard state != .casting, !isComplete else { return }
        scene.performThrow()
        state = .casting
    }

    func reset() {
        castYao = []
        state = .idle
        scene.reset()
    }

    /// Pure accumulation seam — aggregate one Throw's 3 faces into a Yao and
    /// advance. Unit-tested without the scene.
    func appendThrow(_ faces: [CoinFace]) {
        guard castYao.count < 6 else { return }
        castYao.append(Yao(faces: faces))
        state = castYao.count == 6 ? .complete(Hexagram(yao: castYao)) : .idle
    }

    func startMotion() {
        motion.start { [weak self] mag in self?.scene.applyShake(magnitude: mag) }
    }
    func stopMotion() { motion.stop() }

    // MARK: - PhysicsScene callbacks

    private func handleSettle(_ results: [ThrowResult]) {
        haptics.playSettleThunk()
        appendThrow(results.map { $0.faceUp })
    }

    private func handleStateChange(_ s: SettleState) {
        switch s {
        case .throwing, .settling:
            if state != .casting { state = .casting }
        case .idle, .settled:
            break
        }
    }
}
