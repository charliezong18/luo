import SwiftUI
import CoreText

/// Dusk Desk visual tokens (DESIGN.md). Centralized so views don't hardcode hex.
enum Theme {
    /// neutral #14110D — warm near-black desk.
    static let deskBackground = Color(red: 0.078, green: 0.067, blue: 0.051)
    /// primary #ECE3D2 — aged-paper ink.
    static let ink = Color(red: 0.925, green: 0.890, blue: 0.824)
    /// tertiary #DC6A4B — earthen cinnabar accent (one per screen).
    static let cinnabar = Color(red: 0.863, green: 0.416, blue: 0.294)

    /// Serif face for Hanzi/result glyphs. Bundled Noto Serif SC (two static
    /// weights instanced from the variable font). We reference each face by its
    /// PostScript name so no synthetic weighting is applied to the CJK glyphs;
    /// anything `.medium` or heavier maps to the Medium face, else Regular.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let heavier: Set<Font.Weight> = [.medium, .semibold, .bold, .heavy, .black]
        let face = heavier.contains(weight) ? "NotoSerifSC-Medium" : "NotoSerifSC-Regular"
        return .custom(face, size: size)
    }

    /// Register the bundled font files once at launch (they are copied into the
    /// app bundle as resources, not declared via UIAppFonts).
    static func registerBundledFonts() {
        for name in ["NotoSerifSC-Regular", "NotoSerifSC-Medium"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
