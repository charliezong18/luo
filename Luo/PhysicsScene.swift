import Foundation
import SceneKit
import simd
import CoreGraphics

/// The shared physics rig for 落's Rituals (ADR-0005) — a concrete class, not a
/// protocol. Owns the SceneKit scene + the coin rigid body, turns Throw/Shake
/// input into impulses, detects Settle, and emits a `ThrowResult` when the coin
/// comes to rest. The Coin and I Ching ViewModels (Phase 3) will drive it; today
/// the Coin Harness drives it, feeding a `PhysicsConfig` built from its sliders.
///
/// v1 is single-coin. Multi-coin (3-coin 三钱法) is a Phase-3 extension: turn
/// `coinNode` into a collection and emit one `ThrowResult` per coin.
@MainActor
final class PhysicsScene: NSObject, ObservableObject, SCNSceneRendererDelegate {

    /// SceneKit's physics (PhysX) is tuned for ~metre-scale objects; a real
    /// 1.4 cm coin sits far below its stable regime, so fixed-size collision
    /// margins overlap at spawn and the solver flings the coin up and jitters
    /// instead of resting. We model the whole scene `scale`× larger (coin ≈ 0.35 m)
    /// and frame it with the camera. `PhysicsConfig` stays in real-world units;
    /// every length is multiplied by `scale` here. Gravity is kept real (a scaled-up
    /// coin under normal gravity falls slow and stable); impulses are real too.
    static let scale: Double = 25

    /// PhysX holds the resting body a fixed contact margin above the floor
    /// (~0.04 scaled units with the boundingBox shape). We lower the *visual*
    /// coin by this much inside its physics node so it appears to sit on the
    /// felt; during flight the offset is along the coin's own axis and invisible.
    static let contactGap: Double = 0.04

    let scene = SCNScene()
    private var coinNodes: [SCNNode] = []
    private let tableNode: SCNNode
    /// Kept so the ritual can cinematically dolly it from the oblique cast angle to a
    /// straight-down view once the coins settle, making the 钱文 read clearly.
    private let cameraNode = SCNNode()

    private var config: PhysicsConfig
    private let onSettle: ([ThrowResult]) -> Void
    private let onStateChange: (SettleState) -> Void

    // Settle tracker (all coins must be still).
    private var belowThresholdSince: TimeInterval?
    private var throwStartTime: TimeInterval?
    private var currentState: SettleState = .idle
    /// Result emission is armed by `performThrow` and disarmed after one emission,
    /// so post-settle disturbances (a cosmetic nudge, physics jitter) can never
    /// append a duplicate Yao.
    private var armed = false
    /// A coin that settles leaning (against the containment wall / another coin)
    /// gets re-tossed like a real leaner would be; capped to avoid loops.
    private var retossCount = 0
    private static let flatUpDotThreshold: Float = 0.75
    private static let maxRetosses = 2
    /// A tilted coin often lies flat on its own within a second or two — give it
    /// this much stillness before intervening (avoids the "settles then weirdly
    /// pops back up" look).
    private static let leanHoldSeconds: TimeInterval = 1.4
    /// Cumulative angular travel per coin during the current flight (rad). A
    /// flight only records if EVERY coin travelled at least `tumbleThreshold` —
    /// 翻了才算: fairness is judged by what the coins did, not by input force.
    private var cumRotation: [Double] = []
    private static let tumbleThreshold: Double = 4.0
    // Per-coin previous-frame presentation state, for velocity-free stillness.
    private var lastPos: [simd_float3?] = []
    private var lastQuat: [simd_quatf?] = []
    private var lastTickTime: TimeInterval?

    init(config: PhysicsConfig,
         onSettle: @escaping ([ThrowResult]) -> Void,
         onStateChange: @escaping (SettleState) -> Void) {
        self.config = config
        self.onSettle = onSettle
        self.onStateChange = onStateChange
        self.tableNode = Self.makeTableNode()
        super.init()
        let count = max(1, config.coinCount)
        for i in 0..<count {
            let node = Self.makeCoinNode(config: config)
            node.name = "coin\(i)"
            node.position = Self.spawnPosition(config, index: i)
            coinNodes.append(node)
        }
        lastPos = Array(repeating: nil, count: count)
        lastQuat = Array(repeating: nil, count: count)
        buildScene()
        apply(config)
    }

    // MARK: - Scene construction

    private func buildScene() {
        // Warm near-black desk backdrop so the coin reads against it.
        // DESIGN.md `neutral` #14110D — warm, not the cold #141414 of white:0.08.
        scene.background.contents = NSColor_or_UIColor(red: 0.078, green: 0.067, blue: 0.051, alpha: 1)

        // PBR metal is only as good as what it can reflect: a flat scene makes the
        // brass read as black. Give it a warm vertical-gradient environment (dark
        // felt bounce below → a bright overhead key glow up top) so the coin catches
        // moving highlights as it tumbles. Kept dim enough not to fight the Dusk mood.
        scene.lightingEnvironment.contents = Self.makeEnvironmentImage()
        scene.lightingEnvironment.intensity = 1.6

        scene.rootNode.addChildNode(tableNode)
        for node in coinNodes { scene.rootNode.addChildNode(node) }

        let s = CGFloat(Self.scale)
        let cam = SCNCamera()
        cam.zNear = 0.01
        cam.zFar = 10 * Double(s)
        cam.fieldOfView = 50
        cameraNode.camera = cam
        // The oblique cast framing (coins clearly show their faces at a comfortable
        // downward tilt). After the coins settle the ritual dollies this to the
        // straight-down `settledCameraTransform` so all three 钱文 read flat-on.
        cameraNode.position = SCNVector3(0, 0.185 * s, 0.235 * s)
        cameraNode.eulerAngles = SCNVector3(-0.64, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Soft omni fill, kept modest so it doesn't wash out the key light's shadow.
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 400
        light.position = SCNVector3(0, 0.5 * s, 0.15 * s)
        scene.rootNode.addChildNode(light)

        // Ambient raised a touch so the whole felt reads as a surface (not black
        // except one hotspot), while staying moody enough to keep the Dusk mood.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 450
        scene.rootNode.addChildNode(ambient)

        // Key light low from the front-right, so the contact shadow stretches back-
        // left across the felt where the camera can see it (not hidden under the
        // thin coin), reading the coin as grounded.
        let key = SCNNode()
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 800
        keyLight.castsShadow = true
        keyLight.shadowMode = .forward
        keyLight.shadowSampleCount = 16
        keyLight.shadowRadius = 8
        keyLight.shadowColor = NSColor_or_UIColor(white: 0, alpha: 0.75)
        key.light = keyLight
        key.eulerAngles = SCNVector3(-0.6, 0.6, 0)   // ~34° above horizon, yaw right
        scene.rootNode.addChildNode(key)

        // Hero spotlight: a tight warm cone raking the coin center from front-upper-left.
        // The grazing angle catches the raised 钱文 and rim as a bright specular hotspot
        // — the "金光一闪" that separates real metal from a flat disc — while its narrow
        // falloff keeps the surrounding felt dark and moody. Aimed at the coin origin.
        let spot = SCNNode()
        let spotLight = SCNLight()
        spotLight.type = .spot
        spotLight.intensity = 1700
        spotLight.color = NSColor_or_UIColor(red: 1.0, green: 0.90, blue: 0.70, alpha: 1)
        spotLight.spotInnerAngle = 10
        spotLight.spotOuterAngle = 42
        spotLight.attenuationStartDistance = 0
        spotLight.attenuationEndDistance = CGFloat(1.2 * s)
        spot.light = spotLight
        // Low, off to the side and forward — a grazing angle that rakes across the
        // relief instead of flattening it from overhead (which blew out to plastic-
        // bright when the camera pulled straight up). The shallow rake catches the
        // rim + 钱文 edges and lets the far side fall into shadow for depth.
        spot.position = SCNVector3(-0.30 * s, 0.20 * s, 0.26 * s)
        let look = SCNLookAtConstraint(target: coinNodes.first ?? tableNode)
        look.isGimbalLockEnabled = true
        spot.constraints = [look]
        scene.rootNode.addChildNode(spot)
    }

    /// Resting Y for the coin, in scaled scene units: floor top (box centered at
    /// 0, height 0.005 → top at +0.0025) plus half the coin's thickness, plus a
    /// hair of clearance so it drops a fraction of a mm and settles instead of
    /// spawning interpenetrating.
    private static func restY(_ c: PhysicsConfig) -> Double {
        (0.0025 + c.coinThickness / 2 + 0.0002) * scale
    }

    /// Rest position for coin `index`, in scaled scene units. Uses the config's
    /// spawn offset (x,z, real units) if present, else the origin.
    private static func spawnPosition(_ c: PhysicsConfig, index: Int) -> SCNVector3 {
        let off = index < c.spawnOffsets.count ? c.spawnOffsets[index] : SIMD3<Double>(0, 0, 0)
        return SCNVector3(CGFloat(off.x * scale),
                          CGFloat(restY(c)),
                          CGFloat(off.z * scale))
    }

    private static func makeCoinNode(config c: PhysicsConfig) -> SCNNode {
        let r = CGFloat(c.coinRadius * scale)
        let t = CGFloat(c.coinThickness * scale)

        // Physics stays a plain cylinder (boundingBox shape) — the square hole is
        // purely visual and never changes how the coin lands or which face reads up.
        let cyl = SCNCylinder(radius: r, height: t)

        // Brass 五帝-style coin, physically-based so it reads as real metal: metalness
        // ~1 plus the warm `lightingEnvironment` (set in buildScene) give it reflections
        // instead of the flat plastic look .blinn produced. Roughness carries most of
        // the face distinction — polished 阳 vs matte-patina 阴 — with an albedo hue
        // split on top so the faces stay legible mid-tumble.
        func brass(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, rough: CGFloat) -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = NSColor_or_UIColor(red: r, green: g, blue: b, alpha: 1)
            m.metalness.contents = 0.95
            m.roughness.contents = rough
            m.isDoubleSided = true
            return m
        }
        // Sides & chamfer stay a plain aged-brass PBR; the two flat faces get
        // procedurally baked textures (relief 钱文 + verdigris patina) so the coin reads
        // as a real cast 方孔圆钱. See CoinTexture.
        let edge = brass(0.46, 0.34, 0.15, rough: 0.52)

        // Visual: a 方孔圆钱 (outer disc, centered square hole, beveled rim) instead of
        // the bare cylinder — the square hole is the coin's whole visual identity.
        let coin = Self.makeCoinGeometry(radius: r, thickness: t)
#if canImport(UIKit)
        func faceMaterial(_ maps: CoinTexture.Maps) -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.metalness.contents = 1.0
            m.diffuse.contents = maps.albedo
            m.normal.contents = maps.normal
            m.roughness.contents = maps.roughness
            for prop in [m.diffuse, m.normal, m.roughness] {
                prop.wrapS = .clamp
                prop.wrapT = .clamp
            }
            m.isDoubleSided = true
            return m
        }
        // Material order is front / back / sides / chamfer. The back cap lands +Y-up at
        // rest (the physics up-face the settle reader calls 阳/heads), so it wears the
        // plain 背面; the front cap (阴) carries the 乾隆通宝 字面.
        coin.materials = [faceMaterial(CoinTexture.inscribedFace()),
                          faceMaterial(CoinTexture.blankFace()),
                          edge, edge]
#else
        let heads = brass(0.82, 0.62, 0.30, rough: 0.44)
        let tails = brass(0.44, 0.45, 0.28, rough: 0.62)
        coin.materials = [tails, heads, edge, edge]
#endif

        // The child sits lowered by the contact gap so the coin reads as resting on the
        // felt; the parent node carries the physics body. SCNShape extrudes in the XY
        // plane along +Z, so tip it a quarter-turn about X to lay it flat with its faces
        // along ±Y (the cylinder-physics up-axis the settle reader uses). The −quarter
        // turn puts the inscribed 字面 (front cap) up at rest — the coin reads as 阳 and
        // shows its face before the first throw; a flip to 背面 reads as 阴, consistently.
        let visual = SCNNode(geometry: coin)
        visual.name = "coinVisual"
        visual.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        visual.position = SCNVector3(0, -CGFloat(contactGap), 0)

        let node = SCNNode()
        node.name = "coin"
        node.position = SCNVector3(0, CGFloat(Self.restY(c)), 0)
        node.addChildNode(visual)

        let shape = SCNPhysicsShape(geometry: cyl, options: [
            SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.boundingBox.rawValue
        ])
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = CGFloat(c.coinMass)
        body.restitution = CGFloat(c.restitution)
        body.friction = CGFloat(c.friction)
        body.rollingFriction = CGFloat(c.rollingFriction)
        body.damping = CGFloat(c.linearDamping)
        body.angularDamping = CGFloat(c.angularDamping)
        body.allowsResting = true
        node.physicsBody = body
        return node
    }

    /// A 方孔圆钱 solid: an outer disc of `radius` with a centered square hole,
    /// extruded to `thickness` with a small chamfer so the rim reads as a rounded
    /// edge. Built with UIKit's bezier path; the (never-shipped) macOS branch falls
    /// back to a plain cylinder so the file still compiles cross-platform.
    private static func makeCoinGeometry(radius r: CGFloat, thickness t: CGFloat) -> SCNGeometry {
#if canImport(UIKit)
        let path = UIBezierPath(ovalIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r))
        let hs = r * 0.34                        // half the square-hole side (方孔)
        path.append(UIBezierPath(rect: CGRect(x: -hs, y: -hs, width: 2 * hs, height: 2 * hs)))
        path.usesEvenOddFillRule = true          // inner square punches a hole
        path.flatness = r * 0.01                  // keep the disc round at this scale
        let shape = SCNShape(path: path, extrusionDepth: t)
        shape.chamferRadius = t * 0.4
        return shape
#else
        return SCNCylinder(radius: r, height: t)
#endif
    }

    /// An equirectangular environment map for `scene.lightingEnvironment`. Metal is
    /// almost entirely reflection, so a flat gradient makes brass read as plastic —
    /// the fix (per PBR IBL best-practice) is to give it a HIGH-CONTRAST surrounding
    /// with distinct bright "windows" and dark gaps to reflect. We paint, in code:
    ///   • a warm vertical gradient base (dark floor → warm ceiling),
    ///   • two soft bright light-panels (studio softboxes) high on the sphere,
    ///   • a darker band low down so reflections have somewhere black to fall off.
    /// The moving light/dark boundary sweeping across the coin as it tumbles is what
    /// sells it as real metal. Full-width equirect (2:1) so it wraps horizontally.
    private static func makeEnvironmentImage() -> CGImage? {
        let width = 512, height = 256
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        // Base warm vertical gradient (v = 0 bottom → 1 top in CG space).
        let colors = [
            NSColor_or_UIColor(red: 0.015, green: 0.012, blue: 0.008, alpha: 1).cgColor, // deep floor
            NSColor_or_UIColor(red: 0.11,  green: 0.085, blue: 0.055, alpha: 1).cgColor, // warm mid
            NSColor_or_UIColor(red: 0.30,  green: 0.245, blue: 0.165, alpha: 1).cgColor, // upper wall
        ] as CFArray
        guard let grad = CGGradient(colorsSpace: cs, colors: colors,
                                    locations: [0.0, 0.5, 1.0]) else { return nil }
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0),
                               end: CGPoint(x: 0, y: height), options: [])

        // Bright soft light panels (studio softboxes) — the high-contrast features the
        // metal reflects as crisp moving highlights. Radial gradients = soft falloff.
        func panel(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, peak: CGFloat) {
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy); ctx.scaleBy(x: rx, y: ry)
            let g = CGGradient(colorsSpace: cs, colors: [
                NSColor_or_UIColor(white: peak, alpha: 1).cgColor,
                NSColor_or_UIColor(white: peak, alpha: 0).cgColor] as CFArray,
                locations: [0.0, 1.0])!
            ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0,
                                   endCenter: .zero, endRadius: 1,
                                   options: [.drawsBeforeStartLocation]) // additive-ish soft glow
            ctx.restoreGState()
        }
        ctx.setBlendMode(.normal)
        panel(cx: CGFloat(width) * 0.30, cy: CGFloat(height) * 0.72,
              rx: CGFloat(width) * 0.16, ry: CGFloat(height) * 0.22, peak: 0.95)  // main key window
        panel(cx: CGFloat(width) * 0.68, cy: CGFloat(height) * 0.80,
              rx: CGFloat(width) * 0.10, ry: CGFloat(height) * 0.14, peak: 0.55)  // dimmer fill window

        return ctx.makeImage()
    }

    private static func makeTableNode() -> SCNNode {
        let tray = SCNNode()

        let s = CGFloat(scale)

        // Floor — a LARGE thin slab whose edges fall outside the camera frame, so
        // the lower screen reads as one continuous warm desk surface (not a small
        // lit patch floating in black void). Physics floor is this whole slab.
        let floor = SCNBox(width: 1.5 * s, height: 0.005 * s, length: 1.5 * s, chamferRadius: 0)
        // Warm raised-desk felt — DESIGN.md `surface-raised` anchor, nudged up out of
        // pure black so the whole surface reads (not just the key-light hotspot).
        let felt = SCNMaterial(); felt.diffuse.contents = NSColor_or_UIColor(red: 0.17, green: 0.14, blue: 0.10, alpha: 1)
        floor.materials = [felt]
        let floorNode = SCNNode(geometry: floor)
        floorNode.physicsBody = SCNPhysicsBody(
            type: .static, shape: SCNPhysicsShape(geometry: floor, options: nil))
        tray.addChildNode(floorNode)

        // Four INVISIBLE containment walls at a small radius, well inside the framed
        // floor, so a hard Throw keeps the coins near center and in view. Fully
        // transparent (alpha 0) — they contain physically but never draw.
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = NSColor_or_UIColor(white: 0, alpha: 0)
        wallMat.transparency = 0
        let h: CGFloat = 0.14 * s, t: CGFloat = 0.004 * s, span: CGFloat = 0.15 * s
        let walls: [(SCNVector3, CGFloat, CGFloat)] = [
            (SCNVector3(span/2, h/2, 0), t, span),   // +X
            (SCNVector3(-span/2, h/2, 0), t, span),  // -X
            (SCNVector3(0, h/2, span/2), span, t),   // +Z
            (SCNVector3(0, h/2, -span/2), span, t),  // -Z
        ]
        for (pos, w, l) in walls {
            let box = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
            box.materials = [wallMat]
            let n = SCNNode(geometry: box)
            n.position = pos
            n.physicsBody = SCNPhysicsBody(
                type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
            tray.addChildNode(n)
        }
        return tray
    }

    // MARK: - Config

    /// Adopt a new config and push it to the world + body. Called once at init,
    /// and live by the Harness as its sliders move; production Rituals build the
    /// scene with `PhysicsConfig.v1` and never call this again.
    func apply(_ config: PhysicsConfig) {
        self.config = config
        // Gravity stays at its real value (NOT scaled with lengths): a scaled-up
        // coin under normal gravity falls slow and floaty, which keeps PhysX in a
        // stable regime (high gravity × a 1/60 s step tunnels the coin through the
        // floor) and gives the throw long hang time to show its tumble.
        scene.physicsWorld.gravity = SCNVector3(0, -CGFloat(config.gravity), 0)
        for coinNode in coinNodes {
            if let body = coinNode.physicsBody {
                body.mass = CGFloat(config.coinMass)
                body.restitution = CGFloat(config.restitution)
                body.friction = CGFloat(config.friction)
                body.rollingFriction = CGFloat(config.rollingFriction)
                body.damping = CGFloat(config.linearDamping)
                body.angularDamping = CGFloat(config.angularDamping)
            }
            if let cyl = coinNode.childNode(withName: "coinVisual", recursively: false)?
                .geometry as? SCNCylinder {
                cyl.radius = CGFloat(config.coinRadius * Self.scale)
                cyl.height = CGFloat(config.coinThickness * Self.scale)
            }
        }
    }

    // MARK: - Camera dolly

    /// Oblique cast framing (what you throw from) — the comfortable downward tilt.
    private var castCamPosition: SCNVector3 {
        let s = CGFloat(Self.scale); return SCNVector3(0, 0.185 * s, 0.235 * s)
    }
    private let castCamEuler = SCNVector3(-0.64, 0, 0)

    /// Straight-down framing (what the result rests in) — a near-top-down view so all
    /// three coins' 钱文 read flat-on without perspective squash.
    private var settledCamPosition: SCNVector3 {
        let s = CGFloat(Self.scale); return SCNVector3(0, 0.34 * s, 0.012 * s)
    }
    private let settledCamEuler = SCNVector3(-1.52, 0, 0)   // ~87° down, essentially top-down

    /// Ease the camera between the two framings. Called with `toSettled: true` when the
    /// coins come to rest (slow, cinematic pull overhead) and `false` on the next throw
    /// (quicker return to the cast angle).
    private func dollyCamera(toSettled: Bool, duration: TimeInterval) {
        SCNTransaction.begin()
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        SCNTransaction.animationDuration = duration
        cameraNode.position = toSettled ? settledCamPosition : castCamPosition
        cameraNode.eulerAngles = toSettled ? settledCamEuler : castCamEuler
        SCNTransaction.commit()
    }

    // MARK: - Actions

    func reset() {
        for (i, coinNode) in coinNodes.enumerated() {
            guard let body = coinNode.physicsBody else { continue }
            body.clearAllForces()
            body.velocity = SCNVector3Zero
            body.angularVelocity = SCNVector4Zero
            coinNode.position = Self.spawnPosition(config, index: i)
            coinNode.eulerAngles = SCNVector3Zero
            body.resetTransform()
        }
        belowThresholdSince = nil
        throwStartTime = nil
        armed = false
        retossCount = 0
        cumRotation = Array(repeating: 0, count: coinNodes.count)
        lastPos = Array(repeating: nil, count: coinNodes.count)
        lastQuat = Array(repeating: nil, count: coinNodes.count)
        dollyCamera(toSettled: false, duration: 0.5)
        publishState(.idle)
    }

    /// Launch the coin: a center lift impulse for hang time plus a tumble torque
    /// about a random horizontal axis, so it flips face-over-face like a flicked
    /// coin rather than popping straight up. The button's fixed impulse always
    /// tumbles fully, so a tapped Throw always records.
    func performThrow() {
        reset()
        armed = true
        retossCount = 0
        for coinNode in coinNodes {
            guard let body = coinNode.physicsBody else { continue }
            let jitter = Double.random(in: -config.throwHorizontalJitter...config.throwHorizontalJitter)
            let jitter2 = Double.random(in: -config.throwHorizontalJitter...config.throwHorizontalJitter)
            body.applyForce(SCNVector3(CGFloat(jitter),
                                       CGFloat(config.throwLinearImpulse),
                                       CGFloat(jitter2)), asImpulse: true)
            let theta = Double.random(in: 0 ..< 2 * Double.pi)
            body.applyTorque(SCNVector4(CGFloat(cos(theta)), 0, CGFloat(sin(theta)),
                                        CGFloat(config.throwAngularImpulse)), asImpulse: true)
        }
        publishState(.throwing)
    }

    /// Continuous physical coupling to the device shake — one straight line, no
    /// tiers. `fraction` scales a full throw's impulse (torque scales with f² so
    /// a gentle dab stirs without flipping). From rest a plausibly-castable
    /// impulse starts an armed flight from wherever the coins lie (no respawn —
    /// real coins get flung from where they sit); mid-flight impulses keep
    /// feeding energy in, so the tray follows the hand. Whether the flight
    /// RECORDS is decided at settle purely by what the coins did (`tumbled`).
    func shakeImpulse(fraction: Double) {
        let f = min(max(fraction, 0), 1.8)
        let inFlight = currentState == .throwing || currentState == .settling
        if !inFlight {
            // Below this a coin physically cannot tumble to a countable flight;
            // respond with deaf-to-the-state-machine jiggle only.
            if f >= 0.35 {
                armed = true
                retossCount = 0
                cumRotation = Array(repeating: 0, count: coinNodes.count)
                belowThresholdSince = nil
                throwStartTime = nil
                dollyCamera(toSettled: false, duration: 0.3)
                publishState(.throwing)
            }
        } else {
            // Keep feeding energy: push the settle-timeout window forward so a
            // sustained shake can't get force-read mid-motion.
            throwStartTime = nil
        }
        let scale = inFlight ? 0.5 : 1.0
        for coinNode in coinNodes {
            guard let body = coinNode.physicsBody else { continue }
            let lift = f * config.throwLinearImpulse * scale
            let jx = Double.random(in: -0.3...0.3) * lift
            let jz = Double.random(in: -0.3...0.3) * lift
            body.applyForce(SCNVector3(CGFloat(jx), CGFloat(lift), CGFloat(jz)),
                            asImpulse: true)
            let theta = Double.random(in: 0 ..< 2 * Double.pi)
            body.applyTorque(SCNVector4(CGFloat(cos(theta)), 0, CGFloat(sin(theta)),
                                        CGFloat(config.throwAngularImpulse * f * f * scale)),
                             asImpulse: true)
        }
    }

    /// Gently unstick a coin that settled leaning — a small tip-over nudge, the
    /// way a fingertip would lay a leaner flat, NOT a re-throw (no mid-air spin).
    private func retoss(_ coinNode: SCNNode) {
        guard let body = coinNode.physicsBody else { return }
        body.applyForce(SCNVector3(0, CGFloat(config.throwLinearImpulse * 0.22), 0),
                        asImpulse: true)
        let theta = Double.random(in: 0 ..< 2 * Double.pi)
        body.applyTorque(SCNVector4(CGFloat(cos(theta)), 0, CGFloat(sin(theta)),
                                    CGFloat(config.throwAngularImpulse * 0.3)),
                         asImpulse: true)
    }

    // MARK: - Per-frame Settle detection

    nonisolated func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        Task { @MainActor in self.tickSettle(time: time) }
    }

    private func tickSettle(time: TimeInterval) {
        guard !coinNodes.isEmpty else { return }
        var allStill = true
        let haveHistory = lastTickTime != nil
        let dt = Float(time - (lastTickTime ?? time))

        for (i, coinNode) in coinNodes.enumerated() {
            let pres = coinNode.presentation
            let p = pres.simdWorldTransform.columns.3
            let posV = simd_float3(p.x, p.y, p.z)
            let quat = pres.simdOrientation
            if haveHistory, dt > 0, let lp = lastPos[i], let lq = lastQuat[i] {
                let linSpeed = Double(simd_length(posV - lp) / dt) / Self.scale
                let dotq = min(1, abs(simd_dot(quat.vector, lq.vector)))
                let angSpeed = Double(2 * acos(dotq) / dt)
                if currentState == .throwing || currentState == .settling, i < cumRotation.count {
                    cumRotation[i] += angSpeed * Double(dt)
                }
                if !(linSpeed < config.settleLinearThreshold && angSpeed < config.settleAngularThreshold) {
                    allStill = false
                }
            } else {
                allStill = false
            }
            lastPos[i] = posV
            lastQuat[i] = quat
        }
        lastTickTime = time
        if !haveHistory { return }

        // Outside an armed throw the state machine is deliberately deaf: a nudge
        // or physics jitter moving settled coins must never re-enter the pipeline
        // (a spurious throwing→settled cycle emits nothing, but strands the VM
        // in .casting — buttons dead). Only performThrow starts a flight.
        let inFlight = currentState == .throwing || currentState == .settling
        guard inFlight else { return }

        if throwStartTime == nil { throwStartTime = time }
        let timedOut = time - (throwStartTime ?? time) >= config.settleTimeout

        if allStill {
            if currentState == .throwing { publishState(.settling) }
            if belowThresholdSince == nil { belowThresholdSince = time }
        } else {
            belowThresholdSince = nil
        }
        let heldStill = belowThresholdSince.map { time - $0 >= config.settleHoldSeconds } ?? false

        if heldStill || timedOut {
            let tumbledAll = !cumRotation.isEmpty
                && cumRotation.allSatisfy { $0 >= Self.tumbleThreshold }
            // A coin resting tilted past the flatness threshold (leaning on the
            // wall or another coin) has no honest face. Only worth fixing on a
            // flight that will record — and only after giving the coin time to
            // lie flat by itself (a tipping coin usually does within a second
            // or two; intervening instantly looks like it "pops back up").
            if armed, tumbledAll, retossCount < Self.maxRetosses {
                let leaning = coinNodes.filter {
                    abs($0.presentation.simdWorldTransform.columns.1.y) < Self.flatUpDotThreshold
                }
                if !leaning.isEmpty {
                    let stillFor = belowThresholdSince.map { time - $0 } ?? 0
                    if stillFor < Self.leanHoldSeconds, !timedOut { return }
                    retossCount += 1
                    belowThresholdSince = nil
                    throwStartTime = time   // restart the settle-timeout window
                    for coinNode in leaning { retoss(coinNode) }
                    publishState(.throwing)
                    return
                }
            }
            let results = makeResults()
            belowThresholdSince = nil
            throwStartTime = nil
            if armed, tumbledAll {
                // Cinematic pull to a top-down view so the settled 钱文 reads
                // clearly — the reading moment. Void flights stay framed wide.
                dollyCamera(toSettled: true, duration: 1.1)
            }
            publishState(.settled(results.first?.faceUp ?? .heads))
            if armed {
                armed = false
                onSettle(results)
            }
        }
    }

    private func isSettledState(_ s: SettleState) -> Bool {
        if case .settled = s { return true }
        return false
    }

    /// The settled face — binary by the sign of the coin's up-vector. On a flat
    /// tray an edge landing is vanishingly unlikely, so we don't model `.edge`
    /// here (that case exists only for a live mid-flight reader, unused for now).
    private func face(of coinNode: SCNNode) -> CoinFace {
        coinNode.presentation.simdWorldTransform.columns.1.y >= 0 ? .heads : .tails
    }

    private func makeResults() -> [ThrowResult] {
        coinNodes.enumerated().map { (i, coinNode) in
            let m = coinNode.presentation.simdWorldTransform
            let p = m.columns.3
            let realPos = simd_float3(p.x, p.y, p.z) / Float(Self.scale)
            return ThrowResult(id: i,
                               position: realPos,
                               orientation: coinNode.presentation.simdOrientation,
                               faceUp: face(of: coinNode),
                               tumbled: i < cumRotation.count
                                   && cumRotation[i] >= Self.tumbleThreshold)
        }
    }

    private func publishState(_ s: SettleState) {
        currentState = s
        let captured = s
        Task { @MainActor in self.onStateChange(captured) }
    }
}

// MARK: - Platform color shim
// Resolved to UIColor on iOS, NSColor on macOS. Keeps SceneKit material code
// platform-clean without an `#if canImport(UIKit)` smear at every call-site.
#if canImport(UIKit)
import UIKit
typealias NSColor_or_UIColor = UIColor
#else
import AppKit
typealias NSColor_or_UIColor = NSColor
#endif
