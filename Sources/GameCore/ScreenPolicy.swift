import Foundation

public struct ScreenPolicy: Sendable {
  public private(set) var isBlank = false
  public private(set) var lastInteraction: TimeInterval = 0
  public var delay: TimeInterval = 10

  public init() {}

  public mutating func interact(at time: TimeInterval) {
    lastInteraction = time
  }

  public mutating func reveal(at time: TimeInterval) {
    isBlank = false
    lastInteraction = time
  }

  public mutating func hide() { isBlank = true }

  public mutating func tick(at time: TimeInterval, enabled: Bool, protected: Bool) {
    guard enabled, !protected, delay > 0 else { return }
    if time - lastInteraction >= delay { isBlank = true }
  }
}
