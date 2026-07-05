import Foundation
import simd

/// Outcome of a single coin settling after a Throw (ADR-0005). A value type
/// emitted by `PhysicsScene`; the Ritual ViewModels read `faceUp` (Coin → first
/// coin; I Ching → aggregate 3 coins' faces into a Yao).
struct ThrowResult {
    /// Per-coin id within a Throw. 0 for the single-coin Coin ritual; 0…2 once
    /// the I Ching ritual throws three coins (Phase 3).
    let id: Int
    /// Resting position in real-world units (scene units ÷ scene scale).
    let position: SIMD3<Float>
    /// Resting orientation.
    let orientation: simd_quatf
    /// Which face landed up. Binary by design — a flat tray makes an edge landing
    /// vanishingly unlikely, and `PhysicsScene` collapses it to the nearer face.
    let faceUp: CoinFace
    /// Whether this coin actually tumbled enough in flight for the landing to be
    /// a fair random read (翻了才算). A gentle hop that never flips reports
    /// `false`, and the ViewModels discard the whole Throw instead of reading it.
    let tumbled: Bool
}

/// Which face of the coin is up. `edge` exists only for the live face reader; a
/// settled `ThrowResult.faceUp` is always `heads` or `tails`.
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

/// Live Settle state the UI shows above the controls.
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
