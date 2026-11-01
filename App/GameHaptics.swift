import CoreHaptics

@MainActor
final class GameHaptics {
  private var engine: CHHapticEngine?
  private var player: (any CHHapticPatternPlayer)?

  @discardableResult
  func play(_ alert: HalfAlert) -> Bool {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
    do {
      if engine == nil {
        let created = try CHHapticEngine()
        created.playsHapticsOnly = true
        created.isAutoShutdownEnabled = true
        engine = created
      }
      guard let engine else { return false }
      try engine.start()
      let event = CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
        ],
        relativeTime: 0,
        duration: alert == .halfEnd ? 1.0 : 0.2
      )
      let pattern = try CHHapticPattern(events: [event], parameters: [])
      player = try engine.makePlayer(with: pattern)
      try player?.start(atTime: CHHapticTimeImmediate)
      return true
    } catch {
      engine = nil
      player = nil
      return false
    }
  }
}
