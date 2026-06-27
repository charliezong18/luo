import Foundation
import SwiftUI

/// Tunable physics constants for the Coin Harness (ADR-0007 Phase 1).
/// These knobs are the *purpose* of the Harness — Charlie tunes them by feel,
/// the converged values get baked into `PhysicsScene` constants for v1,
/// and this whole file is then discarded.
@MainActor
final class PhysicsParams: ObservableObject {

    // MARK: Coin geometry
    /// Coin mass (kg). Real US quarter ≈ 0.00567. Game-feel range exaggerates.
    @Published var coinMass: Double = 0.01
    /// Coin radius (m). Real US quarter ≈ 0.01213.
    @Published var coinRadius: Double = 0.014
    /// Coin thickness (m). Real US quarter ≈ 0.00175.
    @Published var coinThickness: Double = 0.002

    // MARK: World forces
    /// Gravity magnitude (m/s²). Real-world 9.81; lower values give
    /// floatier hang-time which often *reads* more tactile on-screen.
    @Published var gravity: Double = 9.81

    // MARK: Contact response
    /// Restitution (bounciness), 0–1. Coin-on-desk ≈ 0.15–0.35.
    @Published var restitution: Double = 0.25
    /// Sliding friction, 0–1.
    @Published var friction: Double = 0.55
    /// Rolling friction, 0–1. Higher = coin spins down faster after settling on edge.
    @Published var rollingFriction: Double = 0.2

    // MARK: Damping
    /// Linear damping (air resistance), 0–1.
    @Published var linearDamping: Double = 0.05
    /// Angular damping (spin decay), 0–1.
    @Published var angularDamping: Double = 0.1

    // MARK: Settle detector
    /// Linear speed (m/s) below which the coin counts as "stilling".
    @Published var settleLinearThreshold: Double = 0.02
    /// Angular speed (rad/s) below which the coin counts as "stilling". The
    /// stillness estimate comes from frame-to-frame orientation deltas, which
    /// carry ~1 rad/s of noise even at rest, so this sits above that floor.
    @Published var settleAngularThreshold: Double = 1.5
    /// Seconds the coin must stay below both thresholds before Settle fires.
    @Published var settleHoldSeconds: Double = 0.25

    // MARK: Throw impulse
    /// Vertical launch impulse magnitude (kg·m/s). Sets hang time — higher = the
    /// coin rises further and has more air time to tumble before it lands.
    @Published var throwLinearImpulse: Double = 0.02
    /// Tumble strength: angular impulse about a random HORIZONTAL axis, so the
    /// coin flips face-over-face like a flicked coin. Sized to the scaled coin's
    /// moment of inertia (≈3e-4) — at 0.025 it turns a few times over the arc.
    @Published var throwAngularImpulse: Double = 0.025
    /// Random horizontal scatter on launch.
    @Published var throwHorizontalJitter: Double = 0.003

    /// Reset every knob back to compile-time defaults.
    func resetToDefaults() {
        let fresh = PhysicsParams()
        coinMass = fresh.coinMass
        coinRadius = fresh.coinRadius
        coinThickness = fresh.coinThickness
        gravity = fresh.gravity
        restitution = fresh.restitution
        friction = fresh.friction
        rollingFriction = fresh.rollingFriction
        linearDamping = fresh.linearDamping
        angularDamping = fresh.angularDamping
        settleLinearThreshold = fresh.settleLinearThreshold
        settleAngularThreshold = fresh.settleAngularThreshold
        settleHoldSeconds = fresh.settleHoldSeconds
        throwLinearImpulse = fresh.throwLinearImpulse
        throwAngularImpulse = fresh.throwAngularImpulse
        throwHorizontalJitter = fresh.throwHorizontalJitter
    }
}

/// Result of a single Throw — the Settle face that the coin landed on.
enum CoinFace: String {
    case heads, tails, edge

    var label: String {
        switch self {
        case .heads: return "H"
        case .tails: return "T"
        case .edge:  return "edge"
        }
    }
}

/// Live Settle state the UI shows above the sliders.
enum SettleState: Equatable {
    case idle
    case throwing
    case settling
    case settled(CoinFace)

    var label: String {
        switch self {
        case .idle:           return "ready"
        case .throwing:       return "thrown"
        case .settling:       return "settling…"
        case .settled(let f): return "Settled · \(f.label)"
        }
    }
}
