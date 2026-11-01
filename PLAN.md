# AYSO Gamekeeper build plan

Status: First native prototype implemented. Eleven core tests and two simulator interface tests pass. Physical device trials remain pending.

## Purpose

Build a private iPhone app for the referee's volunteer soccer games.
Target an iPhone 12 mini, strapped lengthwise along the forearm.
Design for use while running, with the other hand available for taps.
The initial use case is youth soccer refereeing.
The app records one active game and keeps completed game records locally.

## Agreed requirements

- Record home and away team names and jersey colors.
- Display a large clock and the current score.
- Record goals, yellow cards, and red cards.
- Store each event's game time, team, and player number.
- Capture event time when recording starts, before player-number entry.
- Allow a player number to be omitted and added later.
- Provide corrections and quick undo.
- Reveal the interface with a tap anywhere on a black screen.
- Consume that first tap; it must not activate a game control.
- Return to black after inactivity, except during event entry.
- Keep the game clock running while the interface is black.
- Use manual reveal rather than motion detection.
- Work offline without an account or server.
- Buzz briefly at 60 and 30 seconds remaining, then buzz longer at the scheduled half end.
- Install the first prototype directly from Xcode with a free Apple Account.

## Proposed first version

### Setup

Show home and away team names with jersey-color dropdowns and colored shirt icons.
Keep text labels visible so color is never the only team identifier.
Offer optional game ID and coach names.
Provide editable half length, with two halves in the first version.
Start with a provisional 25-minute half preset; this is not a claim about local rules.
Confirm the referee's timing practice before finalizing clock behavior.

### Live game

Use a fixed portrait layout sized for the iPhone 12 mini.
Place the period and clock above two clearly labeled team panels.
Each team panel shows its jersey color, score, Goal button, and Card button.
Use large controls, generous spacing, strong contrast, and short labels.
Show a compact recent-event list with an edit route.
Keep period controls separate from scoring controls.

Proposed timing: count upward, with an explicit Pause/Resume control.
Normal goals, cards, and screen blanking do not stop time.
The clock continues beyond the scheduled half length until the referee ends the half.
Ending a half or game requires deliberate confirmation.
Provide halftime and an explicit start for the second half.
Display the current half and cumulative game time clearly.
Define displayed match minutes and stoppage-time labels before implementing event formatting.
Keep exact elapsed seconds so later display changes do not alter the record.

### Goals and cards

Tapping Goal captures the selected team and current game time.
Tapping Card does the same, then offers yellow or red.
Show a large numeric keypad and explicit Save and Cancel actions.
The score changes only after a goal is saved.
Cancelling an entry leaves no event or score change.
Allow editing team, player number, event time, and card type.
Recalculate the score from saved goals after every correction or undo.
Show prior cards for the selected player and flag a second yellow for confirmation.
The prototype warns about prior yellows. The referee records any resulting red card separately.
Linked second-yellow dismissal records remain a later refinement.

### Screen blanking

Keep the app foregrounded during the game and draw a black touch surface when idle.
This is visual blanking, not iOS sleep or a device lock.
Start with a configurable 10-second idle delay and an always-visible option.
Suspend blanking during entry, editing, and confirmation dialogs.
Reveal before presenting any active-game recovery decision.
Restore normal system idle behavior when the game ends or the app leaves the foreground.
Test unexpected touches from sleeves, sweat, and running movement.

### Game record

Show the final score and a chronological list of goals and cards.
Retain finished games locally and allow corrections.
Keep one clear route to resume an unfinished game.
Avoid player rosters, scheduling, calendar sync, accounts, and cloud services in the first version.

## Technical approach

Use Swift and SwiftUI in a standard Xcode project, with no third-party dependencies.
Use separate, small components for game state, timing, storage, and screens.
Store versioned Codable game records in Application Support using atomic writes.
Save every confirmed event and clock or period transition immediately.
Keep the previous valid record when recovery encounters damaged data.

Derive elapsed time from clock anchors; do not count timer callbacks.
Use a monotonic clock during a running process and persist recovery timestamps.
Test backgrounding, screen locking, termination, relaunch, and clock changes.
Detect ambiguous recovery, such as a reboot or changed system clock, and offer correction.
A repeating UI refresh only redraws the clock; it does not determine elapsed time.
Use a controllable clock in tests so timing checks do not require real-time waits.

Choose the deployment target after checking the referee's installed iOS version.
Verify Xcode support before promising installation on that version.
Use native controls where they suit the large-target layout.
Do not request camera, location, contacts, or motion access.

## Build sequence

1. Establish the project and toolchain.
   Confirm phone iOS version, signing, and a compatible simulator runtime.
   Add a README with build, test, and installation instructions.
2. Build the forearm interaction prototype.
   Implement the live layout, jersey colors, black screen, and tap reveal.
   Inspect it at the phone's actual size before expanding the interface.
3. Implement game state and timing.
   Add setup, period transitions, pause/resume, persistence, and recovery.
4. Implement event recording.
   Add goals, cards, player entry, corrections, undo, and score calculation.
5. Complete records and validation.
   Add finished-game review and run the functional and interface checks.
6. Install the prototype on the referee's phone.
   Test readability, reach, blanking, battery use, and reliability with the wrist strap.
   Adjust the interface from these results before treating it as ready for games.

## Acceptance checks

- A simulated game runs through both halves and halftime with the expected elapsed time.
- Delayed UI refreshes do not cause timer drift.
- Blanking and event entry never pause the clock implicitly.
- The reveal tap never records an event or activates a hidden control.
- Event time remains the initial captured time while entering a player number.
- Goals, edits, cancellations, and undo produce the correct score.
- Cards retain the correct team, player, time, and type.
- Relaunch restores committed events, score, and the active period.
- Backgrounding and locking preserve recoverable clock state.
- Recovery never silently replaces damaged data with an empty game.
- All primary controls fit the iPhone 12 mini without scrolling during normal play.
- A physical running trial confirms readable text and usable targets.
- A full game-length device trial measures battery use and checks for heat or interruptions.

Use focused unit tests for timing, period transitions, event corrections, and storage recovery.
Use interface tests for reveal-tap consumption, entry blanking protection, and the core game flow.
Run a clean simulator build and relevant tests before delivery.
Report device-only checks separately until the referee completes them.

## Installation and maintenance

Use Xcode on the referee's Mac and his free Apple Account for the first installation.
The referee completes account sign-in, device trust, and Developer Mode prompts.
Free provisioning expires after seven days and needs a newly signed installation.
Updates should preserve local records when the app identity stays unchanged.
Do not uninstall the app as the normal update procedure.

A paid membership is optional after the prototype proves useful.
TestFlight would provide private installation and updates, with a 90-day build limit.
Paid direct installation is another option, with renewal tied to signing validity.
No public App Store release is needed for the planned prototype.

## Environment observations

Checked on 2026-10-31:

- Repository: `~/ayso_gamekeeper`.
- Xcode 27.2 is selected at `/Applications/Xcode-27.2.0.app`.
- Swift is available through Xcode.
- iOS 27.2 simulator runtime 24B8117 is installed.
- A dedicated Gamekeeper iPhone 12 mini simulator is available.
- Physical iPhone 12 mini: iOS 27.0. Signing and installation succeeded.
- The prototype compiles against the iOS 27.2 simulator SDK, targeting iOS 17 or later.
- Physical launch, vibration, and match use still need device testing.

## Decisions to confirm during implementation

- Half length and whether the referee pauses timing during substitution breaks.
- Cumulative match-minute and added-time display conventions.
- Screen idle delay after a physical running trial.
- Vibration duration and strength after testing the phone in its wrist strap.

## Prototype delivery notes

Core timing and persistence tests run on the Mac through Swift Package Manager.
The native app also compiles as an unsigned iPhone app.
Simulator interface tests cover goal entry, relaunch recovery, and blank-screen interactions.
Actual wrist use remains unverified.
Buzzes require the app to remain active; its black-screen mode keeps it active.
Locking the phone or switching apps can prevent buzzes.
Missed warnings do not replay on return.
See README.md for installation and validation commands.
