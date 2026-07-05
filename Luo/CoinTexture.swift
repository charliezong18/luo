import Foundation
import CoreGraphics
import CoreText

#if canImport(UIKit)
import UIKit

/// Procedurally-baked PBR textures for the coin faces — no bundled art. Each face
/// returns an albedo + normal + roughness map, generated once at scene build. The
/// square-hole cash coin (方孔圆钱) gets two distinct faces:
///   • 字面 (inscribed): 乾隆通宝 in relief around the hole, aged-bronze patina.
///   • 背面 (blank):     plain 幕 face, same patina, rim only.
/// The relief lives in the *normal* map (so light rakes across the cast strokes);
/// albedo/roughness carry the verdigris aging. Textures are square; the caller maps
/// the coin's path-space UVs onto [0,1] with a `contentsTransform`.
enum CoinTexture {

    /// One face's three PBR maps.
    struct Maps {
        let albedo: CGImage?
        let normal: CGImage?
        let roughness: CGImage?
    }

    static let dim = 1024

    // Generated once per process (the per-pixel Swift loops cost seconds on
    // device, and every coin/scene shares the same two faces). `LuoApp` warms
    // these off-main at launch so the first Ritual entry doesn't pay it.
    private static let inscribedMaps: Maps = make(inscribed: true)
    private static let blankMaps: Maps = make(inscribed: false)

    static func inscribedFace() -> Maps { inscribedMaps }
    static func blankFace() -> Maps { blankMaps }

    // MARK: - Build

    private static func make(inscribed: Bool) -> Maps {
        let s = dim
        let height = heightField(inscribed: inscribed, s: s)
        return Maps(
            albedo: albedoImage(height: height, s: s),
            normal: normalImage(from: height, s: s, strength: 5.5),
            roughness: roughnessImage(height: height, s: s)
        )
    }

    // MARK: - Height field (relief source)

    /// Grayscale height in [0,1] (row-major, y-down): raised outer rim + inner square
    /// rim (内郭/外郭) and, on the 字面, the four raised characters around the hole.
    private static func heightField(inscribed: Bool, s: Int) -> [Float] {
        guard let ctx = CGContext(
            data: nil, width: s, height: s, bitsPerComponent: 8, bytesPerRow: s,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return [Float](repeating: 0.5, count: s * s)
        }
        let f = CGFloat(s)
        let c = f / 2
        // Mid-level field.
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: f, height: f))

        // Raised outer rim (外郭) — a thick bright ring near the edge.
        ctx.setStrokeColor(CGColor(gray: 0.95, alpha: 1))
        ctx.setLineWidth(f * 0.055)
        ctx.strokeEllipse(in: CGRect(x: f * 0.09, y: f * 0.09,
                                     width: f * 0.82, height: f * 0.82))

        // Raised inner square rim (内郭) framing the hole.
        let hole = f * 0.17            // half-side of the square hole
        let inner = hole * 1.5         // rim sits just outside the hole
        ctx.setLineWidth(f * 0.04)
        ctx.stroke(CGRect(x: c - inner, y: c - inner, width: inner * 2, height: inner * 2))

        if inscribed {
            drawInscription(in: ctx, s: s, center: c, holeHalf: hole)
        }

        // Read back into a Float height buffer.
        var out = [Float](repeating: 0.5, count: s * s)
        if let data = ctx.data {
            let p = data.bindMemory(to: UInt8.self, capacity: s * s)
            for i in 0..<(s * s) { out[i] = Float(p[i]) / 255 }
        }
        return out
    }

    /// 開元通寶 (Tang, 621 AD — the archetypal Chinese cash coin), read 對讀:
    /// 開(上) 元(下) 通(右) 寶(左), raised around the hole.
    private static func drawInscription(in ctx: CGContext, s: Int, center c: CGFloat, holeHalf: CGFloat) {
        let f = CGFloat(s)
        let size = f * 0.28            // larger glyphs so the 钱文 reads at coin scale
        // 開元通寶's real calligraphy is Ouyang Xun's clerical-regular (隸楷); STKaiti is
        // the closest system face, falling back to a bold system font if unavailable.
        let font = CTFontCreateWithName((UIFont(name: "STKaiti-SC-Bold", size: size)
            ?? UIFont(name: "STKaiti", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .bold)).fontName as CFString, size, nil)
        let r = (holeHalf + f * 0.5 * 0.5) * 0.96   // character ring radius from center
        // CG is y-up here; place 上 at +y.
        let spots: [(String, CGPoint)] = [
            ("開", CGPoint(x: c,        y: c + r)),
            ("元", CGPoint(x: c,        y: c - r)),
            ("通", CGPoint(x: c + r,    y: c)),
            ("寶", CGPoint(x: c - r,    y: c)),
        ]
        for (ch, pt) in spots {
            let attr = NSAttributedString(string: ch, attributes: [
                .font: font, .foregroundColor: CGColor(gray: 1, alpha: 1)])
            let line = CTLineCreateWithAttributedString(attr)
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let w = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
            ctx.textPosition = CGPoint(x: pt.x - w / 2, y: pt.y - (ascent - descent) / 2)
            CTLineDraw(line, ctx)
        }
    }

    // MARK: - Normal map from height (Sobel)

    private static func normalImage(from h: [Float], s: Int, strength: Float) -> CGImage? {
        var buf = [UInt8](repeating: 0, count: s * s * 4)
        func at(_ x: Int, _ y: Int) -> Float {
            h[min(max(y, 0), s - 1) * s + min(max(x, 0), s - 1)]
        }
        for y in 0..<s {
            for x in 0..<s {
                let gx = at(x + 1, y) - at(x - 1, y)
                let gy = at(x, y + 1) - at(x, y - 1)
                var nx = -gx * strength, ny = -gy * strength, nz: Float = 1
                let inv = 1 / (nx * nx + ny * ny + nz * nz).squareRoot()
                nx *= inv; ny *= inv; nz *= inv
                let i = (y * s + x) * 4
                buf[i]     = UInt8((nx * 0.5 + 0.5) * 255)
                buf[i + 1] = UInt8((ny * 0.5 + 0.5) * 255)
                buf[i + 2] = UInt8((nz * 0.5 + 0.5) * 255)
                buf[i + 3] = 255
            }
        }
        return rgbaImage(&buf, s)
    }

    // MARK: - Albedo (bronze + verdigris patina)

    private static func albedoImage(height h: [Float], s: Int) -> CGImage? {
        var buf = [UInt8](repeating: 0, count: s * s * 4)
        // Aged dark-bronze with patina warmth — no green verdigris, but deliberately
        // dimmer & less saturated than bright gold so it reads as an old, handled coin
        // (包浆), not a shiny new mint. Two muted bronze tones lerped by soft noise.
        let lo = (r: Float(0.40), g: Float(0.30), b: Float(0.15))   // deep shaded bronze
        let hi = (r: Float(0.58), g: Float(0.45), b: Float(0.24))   // muted lit bronze
        for y in 0..<s {
            for x in 0..<s {
                let t = smoothstep(0.3, 0.7, fbm(Float(x), Float(y)))
                let grain = 0.97 + 0.06 * hash(x / 3, y / 3)
                var r = mix(lo.r, hi.r, t) * grain
                var g = mix(lo.g, hi.g, t) * grain
                var b = mix(lo.b, hi.b, t) * grain
                // Colour the relief, not just the normal map: raised strokes (rim + 钱文,
                // height > 0.5) get brightened, and the tight recessed valley ringing each
                // raised stroke reads darker — so the 乾隆通宝 characters carry real tonal
                // contrast and stay legible even where the Sobel normal softens fine lines.
                // Colour the relief only subtly — let the reflection (roughness) carry the
                // legibility, so the 钱文 reads as struck-into-metal, not printed-on-top.
                let raised = h[y * s + x] - 0.5
                let lit: Float = raised > 0.02 ? 1.0 + min(raised, 0.45) * 0.45 : 1.0
                let shade: Float = raised < -0.02 ? 0.72 : 1.0
                let k = lit * shade
                r *= k; g *= k; b *= k
                let i = (y * s + x) * 4
                buf[i]     = u8(r); buf[i + 1] = u8(g); buf[i + 2] = u8(b); buf[i + 3] = 255
            }
        }
        return rgbaImage(&buf, s)
    }

    // MARK: - Roughness (aged unevenness; raised metal a touch smoother)

    private static func roughnessImage(height: [Float], s: Int) -> CGImage? {
        var buf = [UInt8](repeating: 0, count: s * s * 4)
        for y in 0..<s {
            for x in 0..<s {
                // Worn-metal roughness variation (the thing that separates struck metal
                // from plastic): raised rim + 钱文 are rubbed smooth by handling → low
                // roughness / crisp reflection; recessed valleys collect grime → rougher.
                let raised = height[y * s + x] - 0.5           // >0 on rim/chars
                var rough = 0.30 - raised * 0.80               // high points near-mirror, valleys matte
                rough += (fbm(Float(x) + 99, Float(y) + 33) - 0.5) * 0.14   // subtle cast unevenness
                rough = min(max(rough, 0.06), 0.72)
                let g = u8(rough)
                let i = (y * s + x) * 4
                buf[i] = g; buf[i + 1] = g; buf[i + 2] = g; buf[i + 3] = 255
            }
        }
        return rgbaImage(&buf, s)
    }

    // MARK: - Helpers

    private static func rgbaImage(_ buf: inout [UInt8], _ s: Int) -> CGImage? {
        buf.withUnsafeMutableBytes { raw -> CGImage? in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: s, height: s, bitsPerComponent: 8,
                bytesPerRow: s * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            return ctx.makeImage()
        }
    }

    private static func u8(_ v: Float) -> UInt8 { UInt8(min(max(v, 0), 1) * 255) }
    private static func mix(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
    private static func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
        let t = min(max((x - e0) / (e1 - e0), 0), 1); return t * t * (3 - 2 * t)
    }

    /// Deterministic integer hash → [0,1] (no RNG, so textures are reproducible).
    private static func hash(_ x: Int, _ y: Int) -> Float {
        var h = UInt32(bitPattern: Int32(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263))
        h = (h ^ (h >> 13)) &* 1_274_126_177
        return Float(h & 0xFFFF) / Float(0xFFFF)
    }

    /// Two-octave value noise for soft patina blotches.
    private static func fbm(_ x: Float, _ y: Float) -> Float {
        valueNoise(x / 60, y / 60) * 0.6 + valueNoise(x / 22, y / 22) * 0.4
    }

    private static func valueNoise(_ x: Float, _ y: Float) -> Float {
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        let fx = x - Float(x0), fy = y - Float(y0)
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        let a = mix(hash(x0, y0), hash(x0 + 1, y0), sx)
        let b = mix(hash(x0, y0 + 1), hash(x0 + 1, y0 + 1), sx)
        return mix(a, b, sy)
    }
}
#endif
