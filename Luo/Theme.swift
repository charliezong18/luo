import SwiftUI

/// Dusk Desk visual tokens (DESIGN.md). Centralized so views don't hardcode hex.
enum Theme {
    /// neutral #14110D — warm near-black desk.
    static let deskBackground = Color(red: 0.078, green: 0.067, blue: 0.051)
    /// primary #ECE3D2 — aged-paper ink.
    static let ink = Color(red: 0.925, green: 0.890, blue: 0.824)
    /// tertiary #DC6A4B — earthen cinnabar accent (one per screen).
    static let cinnabar = Color(red: 0.863, green: 0.416, blue: 0.294)

    /// Serif face for Hanzi/result glyphs. System serif for MVP (PingFang/Songti
    /// fallback for Chinese); bundling Noto Serif SC is a later polish.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
