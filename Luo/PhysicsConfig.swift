import Foundation

/// Physics constants for `PhysicsScene`, in real-world units. The defaults are
/// the values converged in the Coin Harness (ADR-0007) — production Rituals use
/// `PhysicsConfig.v1`; the Harness builds one live from its sliders so feel-tuning
/// keeps tuning the real scene.
struct PhysicsConfig {

    // Coin geometry. Game-feel values, not real-quarter dimensions.
    var coinMass: Double = 0.01          // kg
    var coinRadius: Double = 0.014       // m
    var coinThickness: Double = 0.002    // m

    // World.
    var gravity: Double = 9.81           // m/s²

    // Contact response.
    var restitution: Double = 0.25       // 0–1 bounciness
    var friction: Double = 0.55
    var rollingFriction: Double = 0.2

    // Damping.
    var linearDamping: Double = 0.05
    var angularDamping: Double = 0.1

    // Settle detection (stillness measured from presentation deltas — SceneKit
    // does not report body velocity in SwiftUI SceneView).
    var settleLinearThreshold: Double = 0.02   // m/s
    var settleAngularThreshold: Double = 1.5   // rad/s (orientation-delta noise ~1)
    var settleHoldSeconds: Double = 0.25       // below thresholds this long → settled
    /// Safety cap: force a settle this long after a Throw even if the coin never
    /// fully stills (e.g. rolling on its edge). Must exceed normal throw-to-rest
    /// (~1.6s here incl. hang time) so it never fires mid-flight; the held-still
    /// path handles the common case. (ADR-0005 says 0.8s, but that's shorter than
    /// the coin's hang time — it would false-settle at apex.)
    var settleTimeout: Double = 4.0

    // Throw impulse.
    var throwLinearImpulse: Double = 0.02      // kg·m/s, sets hang time
    var throwAngularImpulse: Double = 0.025    // tumble about a random horizontal axis
    var throwHorizontalJitter: Double = 0.003

    /// The baked v1 constants production Rituals run on.
    static let v1 = PhysicsConfig()
}
