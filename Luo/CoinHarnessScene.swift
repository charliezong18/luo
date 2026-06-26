import Foundation
import SceneKit
import simd

/// Single-coin SceneKit scene driven by `PhysicsParams`.
/// Owns the coin node, the table node, and a per-frame Settle detector.
@MainActor
final class CoinHarnessScene: NSObject, ObservableObject, SCNSceneRendererDelegate {

    let scene = SCNScene()
    private let coinNode: SCNNode
    private let tableNode: SCNNode

    private weak var params: PhysicsParams?
    private let onSettle: (CoinFace) -> Void
    private let onStateChange: (SettleState) -> Void

    // Settle tracker
    private var belowThresholdSince: TimeInterval?
    private var currentState: SettleState = .idle

    init(params: PhysicsParams,
         onSettle: @escaping (CoinFace) -> Void,
         onStateChange: @escaping (SettleState) -> Void) {
        self.params = params
        self.onSettle = onSettle
        self.onStateChange = onStateChange
        self.coinNode = Self.makeCoinNode(params: params)
        self.tableNode = Self.makeTableNode()
        super.init()
        buildScene()
        applyWorldParams()
    }

    // MARK: - Scene construction

    private func buildScene() {
        // Warm near-black desk backdrop so the coin reads against it.
        // DESIGN.md `neutral` #14110D — warm, not the cold #141414 of white:0.08.
        scene.background.contents = NSColor_or_UIColor(red: 0.078, green: 0.067, blue: 0.051, alpha: 1)
        scene.rootNode.addChildNode(tableNode)
        scene.rootNode.addChildNode(coinNode)

        let cameraNode = SCNNode()
        let cam = SCNCamera()
        // Scene is ~0.2 m across; the SCNCamera default zNear of 1.0 m would
        // clip the entire scene and render a blank frame. Pull the near plane in.
        cam.zNear = 0.001
        cam.zFar = 10
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 0.12, 0.22)
        cameraNode.eulerAngles = SCNVector3(-0.5, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.position = SCNVector3(0.1, 0.4, 0.2)
        scene.rootNode.addChildNode(light)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 300
        scene.rootNode.addChildNode(ambient)
    }

    private static func makeCoinNode(params: PhysicsParams) -> SCNNode {
        let cyl = SCNCylinder(radius: CGFloat(params.coinRadius),
                              height: CGFloat(params.coinThickness))
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

        let node = SCNNode(geometry: cyl)
        node.name = "coin"
        node.position = SCNVector3(0, 0.05, 0)

        let shape = SCNPhysicsShape(geometry: cyl, options: [
            SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.convexHull.rawValue
        ])
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = CGFloat(params.coinMass)
        body.restitution = CGFloat(params.restitution)
        body.friction = CGFloat(params.friction)
        body.rollingFriction = CGFloat(params.rollingFriction)
        body.damping = CGFloat(params.linearDamping)
        body.angularDamping = CGFloat(params.angularDamping)
        body.allowsResting = true
        node.physicsBody = body
        return node
    }

    private static func makeTableNode() -> SCNNode {
        let tray = SCNNode()

        // Floor.
        let floor = SCNBox(width: 0.3, height: 0.005, length: 0.3, chamferRadius: 0)
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
        let h: CGFloat = 0.08, t: CGFloat = 0.004, span: CGFloat = 0.3
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

    // MARK: - Param sync

    /// Re-apply params to physics bodies and world. Called when sliders move.
    func applyWorldParams() {
        guard let p = params else { return }
        scene.physicsWorld.gravity = SCNVector3(0, -CGFloat(p.gravity), 0)
        if let body = coinNode.physicsBody {
            body.mass = CGFloat(p.coinMass)
            body.restitution = CGFloat(p.restitution)
            body.friction = CGFloat(p.friction)
            body.rollingFriction = CGFloat(p.rollingFriction)
            body.damping = CGFloat(p.linearDamping)
            body.angularDamping = CGFloat(p.angularDamping)
        }
        // Geometry resize: rebuild cylinder if radius/thickness changed appreciably.
        if let cyl = coinNode.geometry as? SCNCylinder {
            cyl.radius = CGFloat(p.coinRadius)
            cyl.height = CGFloat(p.coinThickness)
        }
    }

    // MARK: - Actions

    func reset() {
        guard let body = coinNode.physicsBody else { return }
        body.clearAllForces()
        body.velocity = SCNVector3Zero
        body.angularVelocity = SCNVector4Zero
        coinNode.position = SCNVector3(0, 0.05, 0)
        coinNode.eulerAngles = SCNVector3Zero
        belowThresholdSince = nil
        publishState(.idle)
    }

    /// Launch the coin straight up with random spin + jitter.
    func performThrow() {
        guard let p = params, let body = coinNode.physicsBody else { return }
        reset()
        let jitter = Double.random(in: -p.throwHorizontalJitter...p.throwHorizontalJitter)
        let jitter2 = Double.random(in: -p.throwHorizontalJitter...p.throwHorizontalJitter)
        let impulse = SCNVector3(CGFloat(jitter),
                                 CGFloat(p.throwLinearImpulse),
                                 CGFloat(jitter2))
        body.applyForce(impulse, asImpulse: true)
        let ax = Double.random(in: -1...1)
        let ay = Double.random(in: -1...1)
        let az = Double.random(in: -1...1)
        let norm = sqrt(ax*ax + ay*ay + az*az)
        let nx = ax / norm, ny = ay / norm, nz = az / norm
        let torque = SCNVector4(CGFloat(nx),
                                CGFloat(ny),
                                CGFloat(nz),
                                CGFloat(p.throwAngularImpulse))
        body.applyTorque(torque, asImpulse: true)
        publishState(.throwing)
    }

    /// Apply an externally-sourced impulse (e.g. from a real device shake).
    func applyShake(magnitude: Double) {
        guard let p = params, let body = coinNode.physicsBody else { return }
        let scaled = min(magnitude, 5.0) * p.throwLinearImpulse
        body.applyForce(SCNVector3(0, CGFloat(scaled), 0), asImpulse: true)
        publishState(.throwing)
    }

    // MARK: - Per-frame Settle detection

    nonisolated func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        Task { @MainActor in self.tickSettle(time: time) }
    }

    private func tickSettle(time: TimeInterval) {
        guard let p = params, let body = coinNode.physicsBody else { return }
        let v = body.velocity
        let w = body.angularVelocity
        let linSpeed = sqrt(Double(v.x*v.x + v.y*v.y + v.z*v.z))
        // SCNVector4 angularVelocity: (axis.xyz, magnitude in w).
        let angSpeed = abs(Double(w.w))
        let still = linSpeed < p.settleLinearThreshold && angSpeed < p.settleAngularThreshold

        if still {
            if let since = belowThresholdSince {
                if time - since >= p.settleHoldSeconds, !isSettledState(currentState) {
                    let face = readFace()
                    publishState(.settled(face))
                    onSettle(face)
                }
            } else {
                belowThresholdSince = time
                if currentState == .throwing { publishState(.settling) }
            }
        } else {
            belowThresholdSince = nil
            if isSettledState(currentState) { publishState(.throwing) }
        }
    }

    private func isSettledState(_ s: SettleState) -> Bool {
        if case .settled = s { return true }
        return false
    }

    /// Read which face is up by transforming the coin's +Y axis into world space
    /// and inspecting the world-Y component.
    private func readFace() -> CoinFace {
        let m = coinNode.presentation.simdWorldTransform
        let up = simd_float3(m.columns.1.x, m.columns.1.y, m.columns.1.z)
        let dotUp = up.y   // world up is +Y
        if dotUp > 0.7 { return .heads }
        if dotUp < -0.7 { return .tails }
        return .edge
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
