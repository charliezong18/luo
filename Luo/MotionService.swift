import Foundation
import CoreMotion

/// Streams device-motion samples and fires a closure when a "shake" — sustained
/// acceleration above threshold — is detected. v1 uses this to start a Throw;
/// in the Harness we expose it as a toggle so the table-top can be controlled
/// by hand without standing up.
@MainActor
final class MotionService: ObservableObject {

    @Published private(set) var isRunning = false
    @Published private(set) var lastShakeMagnitude: Double = 0

    /// Magnitude (g) above which we declare a shake worth reacting to at all.
    /// Light shakes above this only jiggle the resting coins (cosmetic nudge);
    /// a cast requires `castMagnitude` and up.
    var shakeThreshold: Double = 1.15
    /// Minimum seconds between two consecutive shake fires.
    var shakeCooldown: TimeInterval = 0.4

    /// Magnitude (g) at which a shake counts as a real fling → full Throw.
    static let castMagnitude: Double = 2.4
    /// Maps shake magnitude to `PhysicsScene.performThrow(vigor:)`: the cast
    /// threshold is the tap baseline (fairness floor), harder flings launch
    /// visibly higher. `performThrow` clamps the top end.
    static func vigor(forMagnitude mag: Double) -> Double {
        1.0 + max(0, mag - castMagnitude) / 3.0
    }

    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    private var lastFire: TimeInterval = 0
    private var onShake: ((Double) -> Void)?

    init() {
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        queue.name = "luo.motion.queue"
        queue.maxConcurrentOperationCount = 1
    }

    func start(onShake: @escaping (Double) -> Void) {
        guard manager.isDeviceMotionAvailable, !isRunning else { return }
        self.onShake = onShake
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            Task { @MainActor in self.handle(motion: m) }
        }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        manager.stopDeviceMotionUpdates()
        onShake = nil
        isRunning = false
    }

    private func handle(motion: CMDeviceMotion) {
        let a = motion.userAcceleration   // gravity-subtracted, in g
        let mag = sqrt(a.x*a.x + a.y*a.y + a.z*a.z)
        lastShakeMagnitude = mag
        let now = motion.timestamp
        if mag > shakeThreshold, now - lastFire > shakeCooldown {
            lastFire = now
            onShake?(mag)
        }
    }
}
