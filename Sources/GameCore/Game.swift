import Darwin
import Foundation

public enum Side: String, Codable, CaseIterable, Sendable {
  case home = "Home"
  case away = "Away"
}

public enum Jersey: String, Codable, CaseIterable, Sendable {
  case darkBlue = "Dark blue"
  case lightBlue = "Light blue"
  case red = "Red"
  case gold = "Gold"
  case green = "Green"
  case neonGreen = "Neon green"
  case orange = "Orange"
  case purple = "Purple"
  case white = "White"
  case black = "Black"

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let name = try container.decode(String.self)
    switch name {
    case "Blue": self = .darkBlue
    case "Yellow": self = .gold
    default:
      guard let jersey = Self(rawValue: name) else {
        throw DecodingError.dataCorruptedError(
          in: container, debugDescription: "Unknown jersey color: \(name)")
      }
      self = jersey
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct Team: Codable, Equatable, Sendable {
  public var name: String
  public var jersey: Jersey
  public var coach: String

  public init(name: String, jersey: Jersey, coach: String = "") {
    self.name = name
    self.jersey = jersey
    self.coach = coach
  }
}

public enum EventKind: String, Codable, CaseIterable, Sendable {
  case goal = "Goal"
  case yellow = "Yellow card"
  case red = "Red card"
}

public struct GameEvent: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var half: Int
  public var seconds: TimeInterval
  public var side: Side
  public var kind: EventKind
  public var player: String

  public init(
    id: UUID = UUID(), half: Int, seconds: TimeInterval,
    side: Side, kind: EventKind, player: String = ""
  ) {
    self.id = id
    self.half = half
    self.seconds = seconds
    self.side = side
    self.kind = kind
    self.player = player
  }
}

public enum Phase: String, Codable, Sendable {
  case ready, firstHalf, halftime, secondHalf, finished

  public var title: String {
    switch self {
    case .ready: "Ready for kickoff"
    case .firstHalf: "First half"
    case .halftime: "Halftime"
    case .secondHalf: "Second half"
    case .finished: "Full time"
    }
  }

  public var isPlaying: Bool { self == .firstHalf || self == .secondHalf }
  public var half: Int { self == .secondHalf || self == .finished ? 2 : 1 }
}

public struct ClockSample: Codable, Equatable, Sendable {
  public var wall: Date
  public var continuous: TimeInterval

  public init(wall: Date, continuous: TimeInterval) {
    self.wall = wall
    self.continuous = continuous
  }

  public static var now: Self {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    // Continuous time includes device sleep and is independent of clock corrections.
    let seconds = Double(mach_continuous_time()) * Double(info.numer) / Double(info.denom) / 1e9
    return Self(wall: Date(), continuous: seconds)
  }
}

public enum HalfAlert: String, Codable, CaseIterable, Sendable {
  case oneMinute, thirtySeconds, halfEnd

  public var remaining: TimeInterval {
    switch self {
    case .oneMinute: 60
    case .thirtySeconds: 30
    case .halfEnd: 0
    }
  }

  public var message: String {
    switch self {
    case .oneMinute: "1 minute remaining"
    case .thirtySeconds: "30 seconds remaining"
    case .halfEnd: "Scheduled half time reached"
    }
  }
}

public struct Game: Identifiable, Codable, Equatable, Sendable {
  public var id = UUID()
  public var created = Date()
  public var scheduledStart: Date?
  public var location: String?
  public var home: Team
  public var away: Team
  public var gameNumber: String
  public var halfMinutes: Int
  public private(set) var phase: Phase = .ready
  public private(set) var accumulated: TimeInterval = 0
  public private(set) var anchor: ClockSample?
  public var events: [GameEvent] = []
  public private(set) var alertsFired: Set<HalfAlert> = []

  public init(
    home: Team, away: Team, gameNumber: String = "", halfMinutes: Int = 25,
    scheduledStart: Date? = nil, location: String? = nil
  ) {
    self.home = home
    self.away = away
    self.gameNumber = gameNumber
    self.scheduledStart = scheduledStart
    self.location = location?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.halfMinutes = min(60, max(1, halfMinutes))
  }

  public var displayDate: Date { scheduledStart ?? created }
  public var locationLabel: String {
    let value = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return value.isEmpty ? "Location not recorded" : value
  }

  public var isRunning: Bool { anchor != nil }
  public func team(_ side: Side) -> Team { side == .home ? home : away }
  public func score(_ side: Side) -> Int {
    events.filter { $0.side == side && $0.kind == .goal }.count
  }

  public func elapsed(at sample: ClockSample) -> TimeInterval {
    accumulated + (anchor.map { max(0, sample.continuous - $0.continuous) } ?? 0)
  }

  public func needsClockReview(at sample: ClockSample) -> Bool {
    guard let anchor else { return false }
    let delta = sample.continuous - anchor.continuous
    return delta < 0 || abs(sample.wall.timeIntervalSince(anchor.wall) - delta) > 5
  }

  public mutating func start(at sample: ClockSample) {
    if phase == .ready {
      phase = .firstHalf
    } else if phase == .halftime {
      phase = .secondHalf
      accumulated = 0
      alertsFired = []
    }
    guard phase.isPlaying, anchor == nil else { return }
    anchor = sample
  }

  public mutating func pause(at sample: ClockSample) {
    accumulated = elapsed(at: sample)
    anchor = nil
  }

  public mutating func endPeriod(at sample: ClockSample) {
    guard phase.isPlaying else { return }
    pause(at: sample)
    phase = phase == .firstHalf ? .halftime : .finished
  }

  public mutating func correctClock(seconds: TimeInterval) {
    accumulated = max(0, seconds)
    anchor = nil
    alertsFired = Set(
      HalfAlert.allCases.filter { Double(halfMinutes * 60) - $0.remaining <= accumulated })
  }

  public mutating func consumeAlert(at sample: ClockSample) -> HalfAlert? {
    guard phase.isPlaying, isRunning else { return nil }
    let elapsed = elapsed(at: sample)
    let due = HalfAlert.allCases.filter {
      !alertsFired.contains($0) && elapsed >= Double(halfMinutes * 60) - $0.remaining
    }
    alertsFired.formUnion(due)
    guard let latest = due.last else { return nil }
    // Do not replay stale warnings after the app returns from the background.
    let lateness = elapsed - (Double(halfMinutes * 60) - latest.remaining)
    return lateness <= 2 ? latest : nil
  }

  public func draft(side: Side, kind: EventKind, at sample: ClockSample) -> GameEvent {
    GameEvent(half: phase.half, seconds: elapsed(at: sample), side: side, kind: kind)
  }

  public mutating func save(_ event: GameEvent) {
    if let index = events.firstIndex(where: { $0.id == event.id }) {
      events[index] = event
    } else {
      events.append(event)
    }
  }

  public func minuteLabel(for event: GameEvent) -> String {
    let minute = Int(max(0, event.seconds) / 60) + 1
    let offset = event.half == 2 ? halfMinutes : 0
    if minute > halfMinutes { return "\(offset + halfMinutes)+\(minute - halfMinutes)′" }
    return "\(offset + minute)′"
  }

  public static func clockText(_ seconds: TimeInterval) -> String {
    let whole = Int(max(0, seconds))
    return String(format: "%02d:%02d", whole / 60, whole % 60)
  }
}
