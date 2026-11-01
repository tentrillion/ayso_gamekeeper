import SwiftUI

@main
struct GamekeeperApp: App {
  @StateObject private var controller = GameController()

  var body: some Scene {
    WindowGroup {
      GamekeeperView(controller: controller)
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
    }
  }
}
