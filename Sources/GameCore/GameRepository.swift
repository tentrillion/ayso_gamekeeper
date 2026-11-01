import Foundation

public struct GameArchive: Codable, Equatable, Sendable {
  public var version = 1
  public var games: [Game] = []
  public init(games: [Game] = []) { self.games = games }
}

public struct GameRepository: Sendable {
  public let file: URL
  public init(file: URL) { self.file = file }

  public func load() throws -> GameArchive {
    guard FileManager.default.fileExists(atPath: file.path) else { return GameArchive() }
    let archive = try JSONDecoder().decode(GameArchive.self, from: Data(contentsOf: file))
    guard archive.version == 1 else { throw RepositoryError.unsupportedVersion }
    guard
      archive.games.allSatisfy({ game in
        (1...60).contains(game.halfMinutes) && game.accumulated.isFinite && game.accumulated >= 0
          && game.events.allSatisfy {
            (1...2).contains($0.half) && $0.seconds.isFinite && $0.seconds >= 0
          }
      })
    else { throw RepositoryError.invalidRecord }
    return archive
  }

  public func save(_ archive: GameArchive) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(archive)
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: file.path) {
      // Never replace the last readable backup with a damaged source file.
      _ = try load()
      try Data(contentsOf: file).write(to: file.appendingPathExtension("backup"), options: .atomic)
    }
    try data.write(to: file, options: .atomic)
  }
}

public enum RepositoryError: Error {
  case unsupportedVersion, invalidRecord
}
