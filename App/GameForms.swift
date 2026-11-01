import SwiftUI
import UIKit

struct SetupView: View {
  @ObservedObject var controller: GameController
  @Environment(\.dismiss) private var dismiss
  @State private var home = "Home"
  @State private var away = "Away"
  @State private var homeJersey: Jersey = .darkBlue
  @State private var awayJersey: Jersey = .red
  @State private var homeCoach = ""
  @State private var awayCoach = ""
  @State private var gameNumber = ""
  @State private var halfMinutes = 25
  @State private var scheduledStart = Date()
  @State private var location = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Home team") {
          TextField("Team name", text: $home)
          jerseyPicker($homeJersey, side: .home)
          TextField("Coach (optional)", text: $homeCoach)
        }
        Section("Away team") {
          TextField("Team name", text: $away)
          jerseyPicker($awayJersey, side: .away)
          TextField("Coach (optional)", text: $awayCoach)
        }
        if let error = controller.error { Text(error).foregroundStyle(.red) }
        Section("Game") {
          DatePicker(
            "Date and time", selection: $scheduledStart,
            displayedComponents: [.date, .hourAndMinute])
          TextField("Location (optional)", text: $location).accessibilityIdentifier("gameLocation")
          TextField("Game ID (optional)", text: $gameNumber)
          Stepper("\(halfMinutes) minutes per half", value: $halfMinutes, in: 1...60)
          Text("Two halves. Change the duration to match your game.").font(.footnote)
            .foregroundStyle(.secondary)
        }
        Section {
          Label("Tap once to reveal the screen during play.", systemImage: "hand.tap")
          Label("Games save automatically on this phone.", systemImage: "iphone")
        }.font(.footnote)
      }
      .navigationTitle("New game").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            let game = Game(
              home: Team(
                name: home.trimmingCharacters(in: .whitespacesAndNewlines), jersey: homeJersey,
                coach: homeCoach),
              away: Team(
                name: away.trimmingCharacters(in: .whitespacesAndNewlines), jersey: awayJersey,
                coach: awayCoach),
              gameNumber: gameNumber, halfMinutes: halfMinutes,
              scheduledStart: scheduledStart, location: location
            )
            controller.create(game)
            if controller.game?.id == game.id { dismiss() }
          }.disabled(
            home.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || away.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  private func jerseyPicker(_ selection: Binding<Jersey>, side: Side) -> some View {
    Picker("Jersey color", selection: selection) {
      ForEach(Jersey.allCases, id: \.self) { jersey in
        Label {
          Text(jersey.rawValue)
        } icon: {
          Image(uiImage: jersey.shirtImage).renderingMode(.original)
        }
        .tag(jersey)
      }
    }
    .accessibilityIdentifier("jerseyPicker\(side.rawValue)")
  }
}

struct EventEditor: View {
  @ObservedObject var controller: GameController
  @Environment(\.dismiss) private var dismiss
  @State private var event: GameEvent
  @State private var minutes: String
  @State private var seconds: String
  @State private var confirmDelete = false
  @State private var confirmSecondYellow = false

  init(controller: GameController, event: GameEvent) {
    self.controller = controller
    _event = State(initialValue: event)
    _minutes = State(initialValue: String(Int(event.seconds) / 60))
    _seconds = State(initialValue: String(Int(event.seconds) % 60))
  }

  private var exists: Bool { controller.game?.events.contains { $0.id == event.id } ?? false }
  private var validTime: Bool {
    guard let m = Int(minutes), let s = Int(seconds) else { return false }
    return (0...180).contains(m) && (0...59).contains(s)
  }
  private var previousYellow: Bool {
    guard !event.player.isEmpty else { return false }
    return controller.game?.events.contains {
      $0.id != event.id && $0.side == event.side && $0.player == event.player && $0.kind == .yellow
    } ?? false
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          if let game = controller.game {
            HStack {
              JerseyIcon(jersey: game.team(event.side).jersey)
              Text("\(event.side.rawValue) · \(game.team(event.side).name)").font(.headline)
              Spacer()
              Text(game.minuteLabel(for: event)).font(.headline.monospacedDigit()).foregroundStyle(
                Palette.accent)
            }
          }
          Picker("Event", selection: $event.kind) {
            Text("Goal").tag(EventKind.goal)
            Text("Yellow").tag(EventKind.yellow)
            Text("Red").tag(EventKind.red)
          }.pickerStyle(.segmented)
          VStack(spacing: 4) {
            Text("PLAYER NUMBER").font(.caption.weight(.bold)).tracking(2).foregroundStyle(
              .secondary)
            Text(event.player.isEmpty ? "—" : "#\(event.player)")
              .font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit()
              .accessibilityIdentifier("playerNumber")
            Text("Optional. You can add this later.").font(.caption).foregroundStyle(.secondary)
          }
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10
          ) {
            ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "Clear", "0", "⌫"], id: \.self) {
              key in
              Button {
                switch key {
                case "Clear": event.player = ""
                case "⌫": if !event.player.isEmpty { event.player.removeLast() }
                default: if event.player.count < 3 { event.player += key }
                }
              } label: {
                Text(key).font(
                  .system(size: key == "Clear" ? 16 : 26, weight: .semibold, design: .rounded)
                )
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
              }.buttonStyle(.plain).accessibilityLabel(key == "⌫" ? "Delete digit" : key)
            }
          }
          if previousYellow {
            Label(
              "This player already has a yellow card. Record any resulting red card separately.",
              systemImage: "exclamationmark.triangle.fill"
            )
            .font(.footnote).foregroundStyle(.yellow)
          }
          DisclosureGroup("Correct team or time") {
            VStack(spacing: 14) {
              Picker("Team", selection: $event.side) {
                ForEach(Side.allCases, id: \.self) { Text($0.rawValue).tag($0) }
              }.pickerStyle(.segmented)
              Picker("Half", selection: $event.half) {
                Text("First half").tag(1)
                Text("Second half").tag(2)
              }.pickerStyle(.segmented)
              HStack {
                Text("Half clock")
                Spacer()
                TextField("Min", text: $minutes).frame(width: 55)
                Text(":")
                TextField("Sec", text: $seconds).frame(width: 55)
              }.keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            }.padding(.top, 12)
          }.font(.subheadline)
          Button {
            if previousYellow && event.kind == .yellow {
              confirmSecondYellow = true
            } else {
              save()
            }
          } label: {
            Text(exists ? "Save correction" : "Save \(event.kind.rawValue.lowercased())")
              .font(.headline).frame(maxWidth: .infinity, minHeight: 46)
          }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(!validTime)
            .accessibilityIdentifier("saveEvent")
          if let error = controller.error { Text(error).font(.footnote).foregroundStyle(.red) }
          if exists {
            Button("Delete event", role: .destructive) { confirmDelete = true }.frame(minHeight: 44)
          }
        }.padding(20)
      }.background(Palette.background)
        .navigationTitle(exists ? "Edit event" : "Record event").navigationBarTitleDisplayMode(
          .inline
        )
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .confirmationDialog(
          "Delete this event?", isPresented: $confirmDelete, titleVisibility: .visible
        ) {
          Button("Delete event", role: .destructive) {
            controller.update { $0.events.removeAll { $0.id == event.id } }
            if controller.error == nil { dismiss() }
          }
        }
        .confirmationDialog(
          "Record another yellow for this player?", isPresented: $confirmSecondYellow,
          titleVisibility: .visible
        ) {
          Button("Record yellow card") { save() }
        } message: {
          Text("Any resulting red card must be recorded separately in this prototype.")
        }
    }
  }

  private func save() {
    guard let m = Int(minutes), let s = Int(seconds), validTime else { return }
    // Preserve the originally captured fractional time unless the user changes the displayed time.
    if Int(event.seconds) != m * 60 + s { event.seconds = Double(m * 60 + s) }
    controller.update { $0.save(event) }
    if controller.error == nil { dismiss() }
  }
}

struct RecordView: View {
  @ObservedObject var controller: GameController
  @Environment(\.dismiss) private var dismiss
  @State private var editing: GameEvent?

  var body: some View {
    NavigationStack {
      List {
        if let game = controller.game {
          Section {
            Text(
              "\(game.home.name)  \(game.score(.home)) – \(game.score(.away))  \(game.away.name)"
            ).font(.headline)
            Text(game.phase.title).foregroundStyle(.secondary)
            Label(
              game.displayDate.formatted(date: .abbreviated, time: .shortened),
              systemImage: "calendar")
            Label(game.locationLabel, systemImage: "mappin.and.ellipse")
            ForEach(Side.allCases, id: \.self) { side in
              let team = game.team(side)
              Label {
                Text("\(side.rawValue): \(team.name) · \(team.jersey.rawValue)")
              } icon: {
                JerseyIcon(jersey: team.jersey)
              }
              if !team.coach.isEmpty { Text("Coach: \(team.coach)").font(.footnote) }
            }
          }
          Section("Goals and cards") {
            if game.events.isEmpty { Text("No events recorded.").foregroundStyle(.secondary) }
            ForEach(game.events.sorted { ($0.half, $0.seconds) < ($1.half, $1.seconds) }) { event in
              Button {
                editing = event
              } label: {
                HStack(alignment: .top, spacing: 14) {
                  Text(game.minuteLabel(for: event)).font(.headline.monospacedDigit())
                    .foregroundStyle(Palette.accent)
                  VStack(alignment: .leading, spacing: 4) {
                    Text("\(event.side.rawValue) · \(event.kind.rawValue)").foregroundStyle(
                      .primary)
                    Text(event.player.isEmpty ? "Player not recorded" : "Player #\(event.player)")
                    Text("Half \(event.half) · \(Game.clockText(event.seconds))")
                  }.font(.subheadline)
                  Spacer()
                  Image(systemName: "pencil")
                }
              }.buttonStyle(.plain)
            }
          }
        }
      }.navigationTitle("Game record").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(item: $editing) { EventEditor(controller: controller, event: $0) }
    }
  }
}

struct ClockEditor: View {
  @ObservedObject var controller: GameController
  var requiresReview: Bool
  @Environment(\.dismiss) private var dismiss
  @State private var minutes = "0"
  @State private var seconds = "0"

  private var valid: Bool {
    guard let m = Int(minutes), let s = Int(seconds) else { return false }
    return (0...180).contains(m) && (0...59).contains(s)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(
            requiresReview
              ? "The device clock changed or the phone restarted. Check the half clock before continuing."
              : "Enter the correct elapsed time for this half. The clock will pause when you save.")
          HStack {
            TextField("Minutes", text: $minutes)
            Text("min")
            TextField("Seconds", text: $seconds)
            Text("sec")
          }.keyboardType(.numberPad)
        } footer: {
          if requiresReview {
            Text(
              "The suggested time is the last saved paused duration. Set the correct time yourself."
            )
          }
        }
        if let error = controller.error { Text(error).foregroundStyle(.red) }
        Button("Save paused clock") {
          guard let m = Int(minutes), let s = Int(seconds), valid else { return }
          controller.correctClock(Double(m * 60 + s))
          if controller.error == nil { dismiss() }
        }.disabled(!valid)
      }.navigationTitle("Check clock").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          if !requiresReview {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          }
        }
        .onAppear {
          let value =
            requiresReview
            ? (controller.game?.accumulated ?? 0) : (controller.game?.elapsed(at: .now) ?? 0)
          minutes = String(Int(value) / 60)
          seconds = String(Int(value) % 60)
        }
    }
  }
}
