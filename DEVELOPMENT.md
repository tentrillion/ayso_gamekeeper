# Development and testing

## Game flow verified on 2026-11-01

- All 13 core tests pass, including game details and older-record compatibility.
- Goal entry, blank-screen protection, and the complete game-ending flow pass in the simulator.
- The game-ending test covers cancellation, completion, return navigation, another game, and relaunch.
- Previous games show saved date, time, and location; older games use their creation date and a missing-location label.

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
