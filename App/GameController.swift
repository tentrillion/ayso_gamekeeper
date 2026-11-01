import Combine
import Foundation
import SwiftUI

@MainActor
final class GameController: ObservableObject {
  @Published private(set) var archive = GameArchive()
  @Published var selectedID: UUID?
  @Published var error: String?
  @Published private(set) var loadFailed = false
  @Published var clockReview = false
  private let repository: GameRepository

  init() {
    var directory = URL.applicationSupportDirectory.appending(path: "Gamekeeper")
    #if DEBUG
      if let name = ProcessInfo.processInfo.environment["GAMEKEEPER_TEST_STORE"],
        UUID(uuidString: name) != nil
      {
        directory = directory.appending(path: "UITests").appending(path: name)
      }
    #endif
    repository = GameRepository(file: directory.appending(path: "games.json"))
    reload()
  }

  var game: Game? { archive.games.first { $0.id == selectedID } }
  var hasUnfinishedGame: Bool { archive.games.contains { $0.phase != .finished } }

  func reload() {
    do {
      archive = try repository.load()
      loadFailed = false
      selectedID = archive.games.first { $0.phase != .finished }?.id
      reviewClock()
    } catch {
      loadFailed = true
      self.error =
        "The saved game could not be read. It has been preserved. \(error.localizedDescription)"
    }
  }

  func reviewClock() {
    clockReview = game?.needsClockReview(at: .now) ?? false
  }

  func select(_ id: UUID) {
    selectedID = id
    reviewClock()
  }

  func showLibrary() {
    selectedID = nil
    clockReview = false
  }

  func endPeriod(at sample: ClockSample) {
    guard let game, game.phase.isPlaying else { return }
    let finishesGame = game.phase == .secondHalf
    guard update({ $0.endPeriod(at: sample) }) else { return }
    if finishesGame { showLibrary() }
  }

  func create(_ game: Game) {
    guard !hasUnfinishedGame else { return }
    var next = archive
    next.games.insert(game, at: 0)
    if commit(next) { selectedID = game.id }
  }

  @discardableResult
  func update(_ change: (inout Game) -> Void) -> Bool {
    guard let index = archive.games.firstIndex(where: { $0.id == selectedID }) else { return false }
    var next = archive
    change(&next.games[index])
    return commit(next)
  }

  func pollAlert(at sample: ClockSample) -> HalfAlert? {
    guard !clockReview, let index = archive.games.firstIndex(where: { $0.id == selectedID }) else {
      return nil
    }
    var next = archive
    let alert = next.games[index].consumeAlert(at: sample)
    guard next.games[index].alertsFired != archive.games[index].alertsFired else { return nil }
    return commit(next) ? alert : nil
  }

  func correctClock(_ seconds: TimeInterval) {
    update { $0.correctClock(seconds: seconds) }
    reviewClock()
  }

  @discardableResult
  private func commit(_ next: GameArchive) -> Bool {
    guard !loadFailed else { return false }
    do {
      try repository.save(next)
      archive = next
      error = nil
      return true
    } catch {
      self.error = "Change not saved. Please retry. \(error.localizedDescription)"
      return false
    }
  }
}
