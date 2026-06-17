import Foundation
#if canImport(CoreHaptics)
import CoreHaptics
#endif

/// Plays haptic cues tied to physics events. v1 cares about the Settle thunk —
/// the "did it land?" confirmation tap. The Harness exposes a single
/// `playSettleThunk()` so Charlie can A/B different sharpness/intensity values
/// against the visual Settle.
@MainActor
final class HapticsService {

    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool
    #else
    private let supportsHaptics: Bool = false
    #endif

    init() {
        #if canImport(CoreHaptics)
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware()
            .supportsHaptics
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { _ in /* no-op for harness */ }
        } catch {
            engine = nil
        }
        #endif
    }

    /// Sharp settle confirmation — short transient with a faint trail.
    func playSettleThunk(intensity: Float = 0.9, sharpness: Float = 0.7) {
        #if canImport(CoreHaptics)
        guard supportsHaptics, let engine else { return }
        let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let transient = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [i, s],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [transient], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Throwaway harness — swallow.
        }
        #endif
    }

    /// Soft tick used while the coin tumbles, in case we want pre-Settle anticipation.
    /// Not wired in Phase 1, but kept ready so Charlie can play with it.
    func playTumbleTick() {
        #if canImport(CoreHaptics)
        guard supportsHaptics, let engine else { return }
        let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
        let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [i, s],
            relativeTime: 0
        )
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {}
        #endif
    }
}
