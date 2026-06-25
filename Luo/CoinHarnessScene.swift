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
        // Dark felt-table backdrop so the coin reads against it.
        scene.background.contents = NSColor_or_UIColor(white: 0.08, alpha: 1)
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
        // Heads = +Y face (gold-ish), Tails = -Y face (silver-ish), edge band.
        let heads = SCNMaterial(); heads.diffuse.contents = NSColor_or_UIColor.systemYellow
        let edge  = SCNMaterial(); edge.diffuse.contents  = NSColor_or_UIColor.systemGray
        let tails = SCNMaterial(); tails.diffuse.contents = NSColor_or_UIColor.lightGray
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
        let plane = SCNBox(width: 0.6, height: 0.005, length: 0.6, chamferRadius: 0)
        let mat = SCNMaterial(); mat.diffuse.contents = NSColor_or_UIColor.darkGray
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, 0, 0)
        let shape = SCNPhysicsShape(geometry: plane, options: nil)
        node.physicsBody = SCNPhysicsBody(type: .static, shape: shape)
        return node
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
