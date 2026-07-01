import Foundation
import SceneKit
import simd

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

    private var config: PhysicsConfig
    private let onSettle: ([ThrowResult]) -> Void
    private let onStateChange: (SettleState) -> Void

    // Settle tracker (all coins must be still).
    private var belowThresholdSince: TimeInterval?
    private var throwStartTime: TimeInterval?
    private var currentState: SettleState = .idle
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
        scene.rootNode.addChildNode(tableNode)
        for node in coinNodes { scene.rootNode.addChildNode(node) }

        let s = CGFloat(Self.scale)
        let cameraNode = SCNNode()
        let cam = SCNCamera()
        cam.zNear = 0.01
        cam.zFar = 10 * Double(s)
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 0.12 * s, 0.22 * s)
        cameraNode.eulerAngles = SCNVector3(-0.5, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Soft omni fill, kept modest so it doesn't wash out the key light's shadow.
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 350
        light.position = SCNVector3(0.1 * s, 0.4 * s, 0.2 * s)
        scene.rootNode.addChildNode(light)

        // Low ambient so the shadowed felt actually darkens (ambient fills shadows).
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 150
        scene.rootNode.addChildNode(ambient)

        // Key light low from the front-right, so the contact shadow stretches back-
        // left across the felt where the camera can see it (not hidden under the
        // thin coin), reading the coin as grounded.
        let key = SCNNode()
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 1000
        keyLight.castsShadow = true
        keyLight.shadowMode = .forward
        keyLight.shadowSampleCount = 16
        keyLight.shadowRadius = 5
        keyLight.shadowColor = NSColor_or_UIColor(white: 0, alpha: 0.75)
        key.light = keyLight
        key.eulerAngles = SCNVector3(-0.6, 0.6, 0)   // ~34° above horizon, yaw right
        scene.rootNode.addChildNode(key)
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
        let cyl = SCNCylinder(radius: CGFloat(c.coinRadius * scale),
                              height: CGFloat(c.coinThickness * scale))
        // Brass 五帝-style coin. Heads (+Y) = bright polished brass, Tails (-Y) =
        // darker patina brass, edge = dark brass. The brightness split keeps the
        // two faces visually distinct (and matches the face the Settle reader picks).
        func brass(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, shine: CGFloat) -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .blinn
            m.diffuse.contents = NSColor_or_UIColor(red: r, green: g, blue: b, alpha: 1)
            m.specular.contents = NSColor_or_UIColor(white: 1, alpha: 1)
            m.shininess = shine
            return m
        }
        let heads = brass(0.83, 0.67, 0.30, shine: 0.9)
        let edge  = brass(0.45, 0.35, 0.14, shine: 0.5)
        let tails = brass(0.60, 0.46, 0.18, shine: 0.6)
        cyl.materials = [edge, heads, tails]   // SCNCylinder order: side, top, bottom

        // Visual lives in a child lowered by the contact gap so the coin reads as
        // resting on the felt; the parent node carries the physics body.
        let visual = SCNNode(geometry: cyl)
        visual.name = "coinVisual"
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

    private static func makeTableNode() -> SCNNode {
        let tray = SCNNode()

        let s = CGFloat(scale)

        // Floor.
        let floor = SCNBox(width: 0.3 * s, height: 0.005 * s, length: 0.3 * s, chamferRadius: 0)
        // Warm raised-desk felt — DESIGN.md `surface-raised` #211B14, a shade up
        // from the backdrop so the coin and its shadow read with depth.
        let felt = SCNMaterial(); felt.diffuse.contents = NSColor_or_UIColor(red: 0.129, green: 0.106, blue: 0.078, alpha: 1)
        floor.materials = [felt]
        let floorNode = SCNNode(geometry: floor)
        floorNode.physicsBody = SCNPhysicsBody(
            type: .static, shape: SCNPhysicsShape(geometry: floor, options: nil))
        tray.addChildNode(floorNode)

        // Four low walls so a hard Throw can't fling the coin off the table into
        // the void. Faint translucent rim — visible enough to read as a tray.
        let wallMat = SCNMaterial()
        // Faint warm rim — DESIGN.md `hairline` #37291A, translucent.
        wallMat.diffuse.contents = NSColor_or_UIColor(red: 0.216, green: 0.161, blue: 0.102, alpha: 0.18)
        let h: CGFloat = 0.08 * s, t: CGFloat = 0.004 * s, span: CGFloat = 0.3 * s
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
        lastPos = Array(repeating: nil, count: coinNodes.count)
        lastQuat = Array(repeating: nil, count: coinNodes.count)
        publishState(.idle)
    }

    /// Launch the coin: a center lift impulse for hang time plus a tumble torque
    /// about a random horizontal axis, so it flips face-over-face like a flicked
    /// coin rather than popping straight up.
    func performThrow() {
        reset()
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

    /// Apply an externally-sourced impulse (e.g. from a real device shake).
    func applyShake(magnitude: Double) {
        let scaled = min(magnitude, 5.0) * config.throwLinearImpulse
        for coinNode in coinNodes {
            coinNode.physicsBody?.applyForce(SCNVector3(0, CGFloat(scaled), 0), asImpulse: true)
        }
        publishState(.throwing)
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

        let inFlight = currentState == .throwing || currentState == .settling
        guard inFlight else {
            if !allStill, isSettledState(currentState) { publishState(.throwing) }
            return
        }

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
            let results = makeResults()
            belowThresholdSince = nil
            throwStartTime = nil
            publishState(.settled(results.first?.faceUp ?? .heads))
            onSettle(results)
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
                               faceUp: face(of: coinNode))
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
