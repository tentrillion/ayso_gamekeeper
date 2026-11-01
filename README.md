# AYSO Gamekeeper

A personal referee app for an iPhone, worn lengthwise on the forearm.
The first prototype uses SwiftUI and stores all game records on the phone.
It has no server, account, analytics, or third-party dependencies.

## Included

- Home and away names, jersey colors, optional coaches, and game ID.
- Two configurable halves, upward half clock, manual pause/resume, and halftime.
- Goal, yellow-card, and red-card entry with a large player-number keypad.
- Captured event time before number entry; the player number is optional.
- Event corrections, deletion, undo, and a chronological game record.
- Score calculation from saved goals.
- Local saves after each confirmed change, with a previous-file backup.
- Running-clock recovery after app relaunch, with review for ambiguous clock changes.
- Black screen after 5, 10, or 20 idle seconds; an always-visible option is also available.
- Tap anywhere to reveal. The reveal tap cannot activate hidden game controls.
- Short buzzes at 60 and 30 seconds remaining; a one-second buzz at scheduled half end.
- Buttons to test the short and long buzz in Screen settings.

The game clock keeps running after the scheduled half end until you end the half.
Buzzes follow pauses and resume with the game clock.
Each alert fires once per half. Correcting the clock rearms future thresholds.
A warning missed while the app is inactive does not replay later.

Keep Gamekeeper open during play. Its own black screen is not the device Lock Screen.
Buzzes are not guaranteed while the phone is locked or another app is active.
The clock still recovers elapsed time when you return.
Test the buzzes with the actual strap before using them in a game.

## Install the prototype

Use a compatible Xcode release for device installation.
The development machine now uses Xcode 27.2 and the iOS 27.2 SDK.
The iOS 27.2 runtime runs a dedicated iPhone 12 mini simulator.
Installation on an iPhone 12 mini running iOS 27.0 succeeded.
Physical launch and match use remain unverified.

1. Open `Gamekeeper.xcodeproj` in Xcode. Use `open -a Xcode Gamekeeper.xcodeproj` if another editor opens it.
2. In Xcode Settings, add your Apple Account.
3. Create `Config/Signing.local.xcconfig` with your team ID and a unique bundle identifier:

   ```xcconfig
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   GAMEKEEPER_BUNDLE_IDENTIFIER = org.example.your-gamekeeper
   ```

   Git ignores this file. Keep these settings local when sharing the project.
   Automatic signing is already enabled. Xcode's Signing & Capabilities panel shows the resolved settings.
   For an existing installation, keep its team and bundle identifier to preserve access to its game records.
4. Connect the phone by cable and accept its Trust prompt.
5. Enable Developer Mode in the phone's Privacy & Security settings when prompted.
6. Select the phone as the run destination and press Run.
7. If launch requires developer trust, open Settings → General → VPN & Device Management and trust your developer account.

No paid membership is needed for this installation.
Free signing expires after seven days; build and install again to renew it.
Keep the same bundle identifier and update the installed app to retain its records.
Deleting the app also deletes its local records.

## Use

1. Create a game. Confirm the half length; 25 minutes is only an editable preset.
2. Start the first half at kickoff.
3. Tap a team's Goal or Card button. Enter a player number, then Save.
4. Tap the latest event or open Record to make corrections.
5. Use Pause only when you intend to stop match time.
6. Confirm End half, then start the second half separately.
7. Confirm End half again to finish the game.

The large clock shows elapsed time within the current half.
Event minutes use the scheduled half length as the second-half offset.
For 25-minute halves, second-half kickoff is minute 26; added time appears as `25+1′` or `50+1′`.
The record also shows the exact half clock to whole seconds.
Exact captured fractional seconds remain stored.

A second yellow shows a warning. Record any resulting red card separately in this prototype.
Clock correction saves a paused clock. Review the result before resuming.
If a saved file is unreadable, the app preserves it and blocks new writes.
A previous valid file is stored as `games.json.backup` in Application Support/Gamekeeper.

## Validation

Run the core tests without an iOS simulator:

```sh
cd ~/ayso_gamekeeper
xcrun swift test --jobs 2
```

Format and lint Swift sources:

```sh
xcrun swift-format format --in-place --recursive App Sources Tests UITests Package.swift
xcrun swift-format lint --strict --recursive App Sources Tests UITests Package.swift
```

Compile an unsigned iPhone app with the installed SDK:

```sh
xcodebuild -project Gamekeeper.xcodeproj -target Gamekeeper \
  -configuration Debug -sdk iphoneos -jobs 2 \
  CODE_SIGNING_ALLOWED=NO \
  SYMROOT="$PWD/DerivedData/Build/Products" \
  OBJROOT="$PWD/DerivedData/Build/Intermediates.noindex" build
```

This produces `DerivedData/Build/Products/Debug-iphoneos/Gamekeeper.app`.
The unsigned artifact cannot be installed directly on an ordinary iPhone.
Use Xcode signing and Run for installation.

Run the interface tests on the dedicated simulator:

```sh
xcodebuild -project Gamekeeper.xcodeproj -scheme Gamekeeper \
  -destination 'platform=iOS Simulator,name=Gamekeeper iPhone 12 mini' \
  -derivedDataPath DerivedData/Simulator -jobs 2 \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

These tests check goal entry, persistence after relaunch, reveal-tap protection, and entry-screen blanking protection.
They use separate records under Application Support/Gamekeeper/UITests and leave normal game records intact.
Open Xcode's Device Hub to watch the simulated phone during testing.
Physical haptics still require a real phone.

## Verified on 2026-10-31

- Xcode 27.2 simulator build succeeds.
- All 11 core tests pass with the new toolchain.
- Both interface tests pass on the iPhone 12 mini with iOS 27.2.
- The updated jersey dropdown passes selection and saved-color checks in the simulator.
- Shirt icons show the selected jersey colors in the dropdown and setup form.
- Swift formatting and lint checks pass.
- The live screen fits the simulated phone; the tested controls are reachable.
- Physical vibration, battery use, and running with the strap remain unverified.

## Device trial checklist

- Check every live-game control at the phone's default text size.
- Verify the reveal tap never adds a goal, opens a card form, or pauses time.
- Leave an entry form open beyond the idle timeout; it must remain visible.
- Start a two-minute test half and check all three buzzes.
- Pause near a warning deadline, then resume; the warning must follow elapsed game time.
- Confirm the half-end buzz does not stop the clock.
- Cancel a goal, save a goal, move it to the other team, then undo or delete it.
- Lock and unlock the phone; verify the clock and saved events recover.
- Close and reopen the app during a test game; verify recovery.
- Run with the strap and check readability, accidental touches, and buzz strength.
- Run a full game-length battery and heat trial.

Device trials remain pending. The app is a prototype, not yet validated for match use.
