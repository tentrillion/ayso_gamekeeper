import Combine
import SwiftUI
import UIKit

private enum Sheet: String, Identifiable {
  case setup, record, settings, clock
  var id: String { rawValue }
}

enum Palette {
  static let accent = Color(red: 0.77, green: 0.96, blue: 0.42)
  static let background = Color(red: 0.035, green: 0.065, blue: 0.065)
  static let panel = Color(red: 0.08, green: 0.12, blue: 0.12)
}

extension Jersey {
  var shirtImage: UIImage {
    (UIImage(systemName: "tshirt.fill") ?? UIImage())
      .withTintColor(UIColor(color), renderingMode: .alwaysOriginal)
  }

  var contrastingInk: Color {
    switch self {
    case .darkBlue, .green, .purple, .black: .white
    default: .black
    }
  }

  var color: Color {
    switch self {
    case .darkBlue: Color(red: 0.08, green: 0.22, blue: 0.55)
    case .lightBlue: Color(red: 0.35, green: 0.75, blue: 1)
    case .red: Color(red: 1, green: 0.32, blue: 0.36)
    case .gold: Color(red: 1, green: 0.75, blue: 0.12)
    case .green: Color(red: 0.12, green: 0.5, blue: 0.26)
    case .neonGreen: Color(red: 0.48, green: 1, blue: 0.1)
    case .orange: .orange
    case .purple: .purple
    case .white: .white
    case .black: Color(white: 0.18)
    }
  }
}

struct JerseyIcon: View {
  let jersey: Jersey

  var body: some View {
    Image(systemName: "tshirt.fill").symbolRenderingMode(.monochrome)
      .foregroundStyle(jersey.color)
      .shadow(color: jersey == .black ? .white.opacity(0.6) : .clear, radius: 1)
  }
}

struct GamekeeperView: View {
  @ObservedObject var controller: GameController
  @Environment(\.scenePhase) private var scenePhase
  @State private var screen = ScreenPolicy()
  @State private var now = ClockSample.now
  @State private var haptics = GameHaptics()
  @State private var buzzMessage: String?
  @State private var buzzTime = 0.0
  @State private var sheet: Sheet?
  @State private var draft: GameEvent?
  @State private var confirmEnd = false
  @State private var confirmUndo = false
  @AppStorage("idleDelay") private var idleDelay = 10.0
  private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

  private var protected: Bool {
    sheet != nil || draft != nil || confirmEnd || confirmUndo || controller.error != nil
      || controller.clockReview
  }

  var body: some View {
    ZStack {
      Palette.background.ignoresSafeArea()
      if screen.isBlank && !protected {
        // The game view is absent from the hit-test tree while the reveal surface is present.
        Color.black.ignoresSafeArea().contentShape(Rectangle())
          .onTapGesture { screen.reveal(at: ClockSample.now.continuous) }
          .accessibilityLabel("Screen blank. Tap to reveal game.")
          .accessibilityAddTraits(.isButton)
          .accessibilityIdentifier("revealScreen")
      } else {
        NavigationStack {
          Group {
            if controller.loadFailed {
              storageFailure
            } else if let game = controller.game {
              liveGame(game)
            } else {
              library
            }
          }
          .toolbarBackground(Palette.background, for: .navigationBar)
          .toolbarBackground(.visible, for: .navigationBar)
        }
        // Reset navigation and toolbar state when opening or leaving a game.
        .id(controller.selectedID)
        .simultaneousGesture(
          DragGesture(minimumDistance: 0).onChanged { _ in
            screen.interact(at: ClockSample.now.continuous)
          })
      }
    }
    .onReceive(ticker) { _ in
      now = .now
      if scenePhase == .active, let alert = controller.pollAlert(at: now) {
        buzzMessage = haptics.play(alert) ? alert.message : "Buzz unavailable · " + alert.message
        buzzTime = now.continuous
      }
      screen.delay = idleDelay
      screen.tick(
        at: now.continuous, enabled: controller.game?.phase.isPlaying == true, protected: protected)
    }
    .onAppear {
      screen.reveal(at: now.continuous)
      updateIdleTimer()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        now = .now
        screen.reveal(at: now.continuous)
        controller.reviewClock()
      }
      updateIdleTimer()
    }
    .onChange(of: controller.game?.phase) { _, _ in updateIdleTimer() }
    .onChange(of: controller.selectedID) { _, _ in
      screen.reveal(at: ClockSample.now.continuous)
      updateIdleTimer()
    }
    .sheet(item: $sheet, onDismiss: { screen.reveal(at: ClockSample.now.continuous) }) { selected in
      switch selected {
      case .setup: SetupView(controller: controller)
      case .record: RecordView(controller: controller)
      case .settings: settings
      case .clock: ClockEditor(controller: controller, requiresReview: false)
      }
    }
    .sheet(item: $draft, onDismiss: { screen.reveal(at: ClockSample.now.continuous) }) { event in
      EventEditor(controller: controller, event: event)
    }
    .sheet(isPresented: $controller.clockReview) {
      ClockEditor(controller: controller, requiresReview: true).interactiveDismissDisabled()
    }
    .alert(
      "Save problem",
      isPresented: Binding(
        get: { controller.error != nil }, set: { if !$0 { controller.error = nil } }
      )
    ) {
      Button("OK") { controller.error = nil }
    } message: {
      Text(controller.error ?? "")
    }
    .confirmationDialog(
      controller.game?.phase == .secondHalf ? "End this game?" : "End this half?",
      isPresented: $confirmEnd, titleVisibility: .visible
    ) {
      Button(
        controller.game?.phase == .firstHalf ? "End first half" : "End game", role: .destructive
      ) {
        controller.endPeriod(at: .now)
      }.accessibilityIdentifier("confirmEndPeriod")
    } message: {
      Text("The clock stops only when you confirm.")
    }
    .confirmationDialog(
      "Undo the last recorded event?", isPresented: $confirmUndo, titleVisibility: .visible
    ) {
      Button("Undo last event", role: .destructive) {
        controller.update { if !$0.events.isEmpty { $0.events.removeLast() } }
      }
    }
  }

  private func updateIdleTimer() {
    UIApplication.shared.isIdleTimerDisabled =
      scenePhase == .active && controller.game?.phase.isPlaying == true
  }

  private var storageFailure: some View {
    ContentUnavailableView {
      Label("Saved game needs attention", systemImage: "externaldrive.badge.exclamationmark")
    } description: {
      Text("Your saved file is preserved. Retry loading before creating another game.")
    } actions: {
      Button("Retry loading") { controller.reload() }.buttonStyle(.borderedProminent)
    }
  }

  private var library: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Button {
          sheet = .setup
        } label: {
          Label("New game", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent).foregroundStyle(.black)
        .disabled(controller.hasUnfinishedGame)
        .accessibilityIdentifier("newGame")

        if controller.hasUnfinishedGame {
          Text("Current game").font(.title2.bold())
          ForEach(controller.archive.games.filter { $0.phase != .finished }) { game in
            gameRow(game)
          }
          Text("Finish the current game before starting another.")
            .font(.footnote).foregroundStyle(.secondary)
        }

        Text("Previous games").font(.title2.bold()).accessibilityIdentifier("previousGames")
        let completed = controller.archive.games.filter { $0.phase == .finished }
          .sorted { $0.displayDate > $1.displayDate }
        if completed.isEmpty {
          Text("Completed games will appear here.").foregroundStyle(.secondary)
        }
        ForEach(completed) { game in
          gameRow(game)
        }
      }.padding(20)
    }
    .background(Palette.background)
    .navigationTitle("Games").navigationBarTitleDisplayMode(.inline)
  }

  private func gameRow(_ game: Game) -> some View {
    Button {
      controller.select(game.id)
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        if game.phase != .finished {
          Text("RESUME GAME").font(.caption.bold()).foregroundStyle(Palette.accent)
        }
        ForEach(Side.allCases, id: \.self) { side in
          HStack {
            JerseyIcon(jersey: game.team(side).jersey)
            Text(game.team(side).name).foregroundStyle(.white)
            Spacer()
            Text("\(game.score(side))").foregroundStyle(.white).monospacedDigit()
          }.font(.headline)
        }
        Label(
          game.displayDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar"
        )
        .accessibilityIdentifier("gameDate")
        Label(game.locationLabel, systemImage: "mappin.and.ellipse")
      }
      .font(.subheadline).foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading).padding()
      .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(game.phase == .finished ? "previousGame" : "resumeGame")
  }

  private func liveGame(_ game: Game) -> some View {
    VStack(spacing: 10) {
      HStack {
        Text(game.phase.title.uppercased()).font(.caption.weight(.bold)).tracking(2)
        Spacer()
        Text(game.isRunning ? "● RUNNING" : "● STOPPED")
          .font(.caption2.weight(.bold)).foregroundStyle(game.isRunning ? Palette.accent : .orange)
      }
      VStack(spacing: 2) {
        Text(Game.clockText(game.elapsed(at: now)))
          .font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
          .minimumScaleFactor(0.6).lineLimit(1).accessibilityIdentifier("gameClock")
        Text(
          now.continuous - buzzTime < 8
            ? (buzzMessage ?? "HALF CLOCK") : "HALF CLOCK  /  \(game.halfMinutes) MIN"
        )
        .font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
      }
      HStack(spacing: 12) {
        teamPanel(game, side: .home)
        teamPanel(game, side: .away)
      }
      if game.phase.isPlaying {
        HStack(spacing: 12) {
          Button {
            controller.update { if $0.isRunning { $0.pause(at: .now) } else { $0.start(at: .now) } }
          } label: {
            Label(
              game.isRunning ? "Pause" : "Resume",
              systemImage: game.isRunning ? "pause.fill" : "play.fill"
            )
            .frame(maxWidth: .infinity, minHeight: 42)
          }.buttonStyle(GameButtonStyle())
          Button(game.phase == .secondHalf ? "End game" : "End half") { confirmEnd = true }
            .frame(minHeight: 42).buttonStyle(GameButtonStyle())
        }
      } else if game.phase != .finished {
        Button {
          controller.update { $0.start(at: .now) }
        } label: {
          Label(
            game.phase == .halftime ? "Start second half" : "Start first half",
            systemImage: "play.fill"
          )
          .frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.borderedProminent).foregroundStyle(.black)
      }
      if let event = game.events.last {
        Button {
          draft = event
        } label: {
          HStack {
            Text(game.minuteLabel(for: event)).font(.headline.monospacedDigit()).foregroundStyle(
              Palette.accent)
            VStack(alignment: .leading) {
              Text("\(event.side.rawValue) · \(event.kind.rawValue)").font(
                .subheadline.weight(.semibold))
              Text(event.player.isEmpty ? "Add player number" : "Player #\(event.player)").font(
                .caption
              ).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "pencil").foregroundStyle(.secondary)
          }.padding(12).background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
      } else {
        Text("Goals and cards appear here.").font(.footnote).foregroundStyle(.secondary).padding(
          .vertical, 12)
      }
      Spacer(minLength: 0)
      HStack {
        Button {
          sheet = .record
        } label: {
          Label("Record", systemImage: "list.bullet")
        }
        .frame(minHeight: 44)
        Spacer()
        if game.phase.isPlaying {
          Button {
            screen.hide()
          } label: {
            Label("Blank", systemImage: "moon.fill")
          }
          .frame(minHeight: 44).accessibilityIdentifier("blankScreen")
        }
      }.font(.subheadline.weight(.semibold))
    }
    .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)
    .background(Palette.background)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          controller.showLibrary()
        } label: {
          Label("Games", systemImage: "chevron.left")
        }.accessibilityIdentifier("backToGames")
      }
      ToolbarItem(placement: .principal) {
        Text(game.gameNumber.isEmpty ? "GAMEKEEPER" : "GAME \(game.gameNumber)")
          .font(.caption.weight(.bold)).tracking(1)
      }
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Screen settings", systemImage: "sun.max") { sheet = .settings }
          if game.phase.isPlaying {
            Button("Correct clock", systemImage: "clock") { sheet = .clock }
          }
          Button("Undo last event", systemImage: "arrow.uturn.backward") { confirmUndo = true }
            .disabled(game.events.isEmpty)
        } label: {
          Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
        }
      }
    }
  }

  private func teamPanel(_ game: Game, side: Side) -> some View {
    let team = game.team(side)
    return VStack(spacing: 8) {
      HStack(spacing: 6) {
        JerseyIcon(jersey: team.jersey)
        Text(side.rawValue.uppercased()).font(.caption.weight(.bold)).tracking(1)
      }
      Text(team.name).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.6)
      Text("\(game.score(side))").accessibilityIdentifier("score\(side.rawValue)").font(
        .system(size: 40, weight: .bold, design: .rounded)
      )
      .monospacedDigit()
      Button {
        draft = game.draft(side: side, kind: .goal, at: .now)
      } label: {
        Label("Goal", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(
        GameButtonStyle(
          fill: team.jersey.color,
          ink: team.jersey.contrastingInk)
      )
      .accessibilityIdentifier("goal\(side.rawValue)")
      .disabled(!game.phase.isPlaying)
      Button {
        draft = game.draft(side: side, kind: .yellow, at: .now)
      } label: {
        Label("Card", systemImage: "rectangle.portrait.fill").frame(
          maxWidth: .infinity, minHeight: 40)
      }.accessibilityIdentifier("card\(side.rawValue)").buttonStyle(
        GameButtonStyle(fill: .white.opacity(0.08), ink: .white)
      ).disabled(
        !game.phase.isPlaying)
    }
    .frame(maxWidth: .infinity).padding(12)
    .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
    .overlay(alignment: .top) {
      Capsule().fill(team.jersey.color).frame(height: 4).padding(.horizontal, 20)
    }
  }

  private var settings: some View {
    NavigationStack {
      Form {
        Picker("Blank after", selection: $idleDelay) {
          Text("5 seconds").tag(5.0)
          Text("10 seconds").tag(10.0)
          Text("20 seconds").tag(20.0)
          Text("Keep visible").tag(0.0)
        }
        Section("Half alerts") {
          Text("Short buzz: 1 minute and 30 seconds remaining. Long buzz: scheduled half end.")
          Button("Test short buzz") { _ = haptics.play(.oneMinute) }
          Button("Test long buzz") { _ = haptics.play(.halfEnd) }
          Text(
            "Keep Gamekeeper open during play. Buzzes work with the app screen black, but not while the phone is locked."
          )
          .font(.footnote).foregroundStyle(.secondary)
        }
        Section {
          Text("Tap the black screen once to reveal it. That tap cannot record an event.")
          Text("The clock continues while the screen is blank. Entry forms stay visible.")
        }
      }.navigationTitle("Screen").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
    }
  }
}

private struct GameButtonStyle: ButtonStyle {
  var fill: Color = Palette.panel
  var ink: Color = Palette.accent
  @Environment(\.isEnabled) private var enabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.weight(.bold))
      .padding(.horizontal, 8)
      .frame(minHeight: 48)
      .foregroundStyle(ink)
      .background(fill, in: RoundedRectangle(cornerRadius: 12))
      .opacity(enabled ? (configuration.isPressed ? 0.65 : 1) : 0.35)
  }
}
