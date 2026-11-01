import Foundation
import Testing

@testable import GameCore

private func sample(_ seconds: Double, wallOffset: Double = 0) -> ClockSample {
  ClockSample(
    wall: Date(timeIntervalSince1970: 1_000_000 + seconds + wallOffset), continuous: 1000 + seconds)
}

private func makeGame() -> Game {
  Game(home: Team(name: "Blue", jersey: .darkBlue), away: Team(name: "Red", jersey: .red))
}

@Test func timingSurvivesLongGapsAndPauses() {
  var game = makeGame()
  game.start(at: sample(0))
  #expect(game.elapsed(at: sample(700)) == 700)
  game.pause(at: sample(710))
  #expect(game.elapsed(at: sample(900)) == 710)
  game.start(at: sample(950))
  #expect(game.elapsed(at: sample(1000)) == 760)
  game.start(at: sample(1010))
  #expect(game.elapsed(at: sample(1020)) == 780)
}

@Test func fullGameKeepsHalvesSeparate() {
  var game = makeGame()
  game.start(at: sample(0))
  #expect(game.elapsed(at: sample(1510)) == 1510)
  game.endPeriod(at: sample(1520))
  #expect(game.phase == .halftime)
  #expect(!game.isRunning)
  game.start(at: sample(1800))
  #expect(game.phase == .secondHalf)
  #expect(game.elapsed(at: sample(1800)) == 0)
  game.endPeriod(at: sample(3300))
  #expect(game.phase == .finished)
  game.start(at: sample(3400))
  #expect(!game.isRunning)
}

@Test func captureBeforeEntryAndCorrectScore() {
  var game = makeGame()
  game.start(at: sample(0))
  var draft = game.draft(side: .home, kind: .goal, at: sample(71.5))
  #expect(game.score(.home) == 0)
  draft.player = "12"
  game.save(draft)
  #expect(game.events.first?.seconds == 71.5)
  #expect(game.elapsed(at: sample(90)) == 90)
  #expect(game.score(.home) == 1)
  draft.side = .away
  game.save(draft)
  #expect(game.events.count == 1)
  #expect(game.score(.home) == 0)
  #expect(game.score(.away) == 1)
  draft.kind = .yellow
  game.save(draft)
  #expect(game.score(.away) == 0)
  #expect(game.events.first?.player == "12")
  game.events.removeLast()
  #expect(game.events.isEmpty)
}

@Test func matchMinuteBoundaries() {
  let game = makeGame()
  for (half, seconds, label) in [
    (1, 0.0, "1′"), (1, 59.9, "1′"), (1, 60, "2′"), (1, 1500, "25+1′"), (2, 0, "26′"),
    (2, 1500, "50+1′"),
  ] {
    #expect(
      game.minuteLabel(for: GameEvent(half: half, seconds: seconds, side: .home, kind: .goal))
        == label)
  }
}

@Test func runningClockRestoresAndDetectsAmbiguousRecovery() throws {
  var game = makeGame()
  game.start(at: sample(0))
  let restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
  #expect(restored.elapsed(at: sample(300)) == 300)
  #expect(!restored.needsClockReview(at: sample(300)))
  #expect(restored.needsClockReview(at: sample(300, wallOffset: 3600)))
  #expect(restored.needsClockReview(at: ClockSample(wall: sample(300).wall, continuous: 5)))
  game.correctClock(seconds: 240)
  #expect(!game.isRunning)
  #expect(game.elapsed(at: sample(400)) == 240)
  #expect(!game.needsClockReview(at: sample(400, wallOffset: 3600)))
}

@Test func blankingProtectsEntryAndDoesNotChangeClock() {
  var game = makeGame()
  game.start(at: sample(0))
  var screen = ScreenPolicy()
  screen.reveal(at: 0)
  screen.tick(at: 12, enabled: true, protected: true)
  #expect(!screen.isBlank)
  screen.reveal(at: 13)
  screen.tick(at: 22, enabled: true, protected: false)
  #expect(!screen.isBlank)
  screen.tick(at: 23, enabled: true, protected: false)
  #expect(screen.isBlank)
  #expect(game.elapsed(at: sample(23)) == 23)
  #expect(game.events.isEmpty)
  screen.reveal(at: 24)
  #expect(!screen.isBlank)
  screen.delay = 0
  screen.tick(at: 1000, enabled: true, protected: false)
  #expect(!screen.isBlank)
}

@Test func archiveRoundTripAndBackup() throws {
  let directory = FileManager.default.temporaryDirectory.appending(
    path: "gamekeeper-test-\(UUID())")
  let repository = GameRepository(file: directory.appending(path: "games.json"))
  #expect(try repository.load().games.isEmpty)
  let first = GameArchive(games: [makeGame()])
  try repository.save(first)
  #expect(try repository.load() == first)
  var second = first
  second.games[0].start(at: sample(0))
  try repository.save(second)
  #expect(try repository.load() == second)
  let backup = GameRepository(file: repository.file.appendingPathExtension("backup"))
  #expect(try backup.load() == first)
}

@Test func corruptedDataIsNeverOverwritten() throws {
  let directory = FileManager.default.temporaryDirectory.appending(
    path: "gamekeeper-test-\(UUID())")
  let repository = GameRepository(file: directory.appending(path: "games.json"))
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let damaged = Data("broken json".utf8)
  try damaged.write(to: repository.file)
  #expect(throws: (any Error).self) { try repository.load() }
  #expect(throws: (any Error).self) { try repository.save(GameArchive()) }
  #expect(try Data(contentsOf: repository.file) == damaged)
}

@Test func halfAlertsFireOnceAtCorrectTimes() throws {
  var game = makeGame()
  game.start(at: sample(0))
  #expect(game.consumeAlert(at: sample(1439)) == nil)
  #expect(game.consumeAlert(at: sample(1440)) == .oneMinute)
  #expect(game.consumeAlert(at: sample(1440.25)) == nil)
  game.pause(at: sample(1445))
  #expect(game.consumeAlert(at: sample(2000)) == nil)
  game.start(at: sample(2000))
  #expect(game.consumeAlert(at: sample(2025)) == .thirtySeconds)
  #expect(game.consumeAlert(at: sample(2055)) == .halfEnd)
  #expect(game.isRunning)
  #expect(game.consumeAlert(at: sample(2056)) == nil)
  var restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
  #expect(restored.consumeAlert(at: sample(2056)) == nil)
  game.endPeriod(at: sample(2060))
  game.start(at: sample(2300))
  #expect(game.consumeAlert(at: sample(3740)) == .oneMinute)
}

@Test func missedAlertsDoNotReplayAndCorrectionsRearmFutureAlerts() {
  var game = makeGame()
  game.start(at: sample(0))
  #expect(game.consumeAlert(at: sample(1490)) == nil)
  #expect(game.alertsFired == [.oneMinute, .thirtySeconds])
  #expect(game.consumeAlert(at: sample(1500)) == .halfEnd)
  game.correctClock(seconds: 1430)
  game.start(at: sample(1600))
  #expect(game.consumeAlert(at: sample(1610)) == .oneMinute)
}

@Test func legacyJerseyColorsRemainReadable() throws {
  let decoder = JSONDecoder()
  #expect(try decoder.decode(Jersey.self, from: Data("\"Blue\"".utf8)) == .darkBlue)
  #expect(try decoder.decode(Jersey.self, from: Data("\"Yellow\"".utf8)) == .gold)
  for jersey in Jersey.allCases {
    #expect(try decoder.decode(Jersey.self, from: JSONEncoder().encode(jersey)) == jersey)
  }
}

@Test func gameDetailsSurviveSaveAndReload() throws {
  let date = Date(timeIntervalSince1970: 1_700_000_000)
  var game = Game(
    home: Team(name: "Home", jersey: .darkBlue),
    away: Team(name: "Away", jersey: .gold),
    scheduledStart: date, location: "  Practice Field  ")
  game.start(at: sample(0))
  game.endPeriod(at: sample(1500))
  game.start(at: sample(1800))
  game.save(game.draft(side: .home, kind: .goal, at: sample(1900)))
  game.endPeriod(at: sample(3300))
  let directory = FileManager.default.temporaryDirectory.appending(
    path: "gamekeeper-test-\(UUID())")
  let repository = GameRepository(file: directory.appending(path: "games.json"))
  try repository.save(GameArchive(games: [game]))
  let saved = try #require(repository.load().games.first)
  #expect(saved.phase == .finished)
  #expect(saved.displayDate == date)
  #expect(saved.locationLabel == "Practice Field")
  #expect(saved.score(.home) == 1)
}

@Test func existingGamesWithoutDetailsRemainReadable() throws {
  var game = makeGame()
  game.start(at: sample(0))
  game.save(game.draft(side: .away, kind: .goal, at: sample(80)))
  var object = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(game)) as? [String: Any])
  object.removeValue(forKey: "scheduledStart")
  object.removeValue(forKey: "location")
  let data = try JSONSerialization.data(withJSONObject: object)
  let restored = try JSONDecoder().decode(Game.self, from: data)
  #expect(restored.displayDate == game.created)
  #expect(restored.locationLabel == "Location not recorded")
  #expect(restored.phase == .firstHalf)
  #expect(restored.elapsed(at: sample(200)) == 200)
  #expect(restored.score(.away) == 1)
  #expect(restored.events == game.events)
}
