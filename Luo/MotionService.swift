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

    /// Magnitude (g) above which motion reaches the coins at all. Low on purpose:
    /// a gentle lift of the device should already stir them (fully analog feel).
    var shakeThreshold: Double = 0.35
    /// Minimum seconds between two consecutive shake fires.
    var shakeCooldown: TimeInterval = 0.3

    /// Magnitude (g) at which a shake counts as a real fling → recorded Throw.
    /// The line exists for fairness only: below it the coins respond physically
    /// but nothing is read (an under-thrown coin barely tumbles, so reading it
    /// would bias the result toward the starting face).
    static let castMagnitude: Double = 2.4
    /// Continuous response curve below the cast line: threshold → ~4% of a
    /// throw's lift, cast line → 100%. One straight line, no steps.
    static func liftFraction(forMagnitude mag: Double) -> Double {
        let f = (mag - 0.35) / (castMagnitude - 0.35)
        return min(max(f, 0.04), 1.0)
    }
    /// Above the cast line the same line keeps climbing: harder fling, higher
    /// launch. `performThrow` clamps the top end (1.8×).
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
