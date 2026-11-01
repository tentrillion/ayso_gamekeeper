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
      let pattern = try Self.pattern(for: alert)
      // A test buzz replaces any pulse still playing; an already finished player may reject stop.
      try? player?.stop(atTime: CHHapticTimeImmediate)
      player = try engine.makePlayer(with: pattern)
      try player?.start(atTime: CHHapticTimeImmediate)
      return true
    } catch {
      engine = nil
      player = nil
      return false
    }
  }

  static func pattern(for alert: HalfAlert) throws -> CHHapticPattern {
    let pulseDuration = alert == .halfEnd ? 1.5 : 0.6
    let starts: [Double] = alert == .halfEnd ? [0, 1.9] : [0, 0.85, 1.7]
    let events = starts.map { start in
      CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: 1),
        ],
        relativeTime: start,
        duration: pulseDuration
      )
    }
    return try CHHapticPattern(events: events, parameters: [])
  }
}
