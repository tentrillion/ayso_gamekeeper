# AYSO Gamekeeper

A simple iPhone app for **in-game soccer reffing**: keep time, record goals, and track cards while on the field.

This is **vibe coded** and intended **solely for the developer's personal use**.
It is a personal project, not an official AYSO app. But it seems to work!

We considered TestFlight, App Store distribution, and direct installation from a Mac; direct installation suited a personal app best.

## During a game

- Set team names, jersey colors, and half length.
- Record each goal or card with its minute, team, and optional player number.
- Get short buzzes with one minute and 30 seconds left, then a longer buzz at half end.
- Blank the screen between checks and tap once to reveal it.
- Correct entries and review the game record. Everything stays on the phone.

Designed for an iPhone 12 mini worn lengthwise along the forearm in a wrist strap.
The clock keeps running until the referee pauses it or ends the half.
Keep the app open during play: its black screen allows alerts, but locking the phone can prevent buzzes.

## Project notes

See [the project plan](PLAN.md) for design decisions and [development notes](DEVELOPMENT.md) for tests and device checks.

## Installation details

<details>
<summary>Install from a Mac with Xcode</summary>

1. Open `Gamekeeper.xcodeproj` in Xcode. If another editor opens it, use `open -a Xcode Gamekeeper.xcodeproj`.
2. Add your Apple Account in Xcode Settings.
3. Create `Config/Signing.local.xcconfig` with your own signing settings:

   ```xcconfig
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   GAMEKEEPER_BUNDLE_IDENTIFIER = org.example.your-gamekeeper
   ```

   This file is ignored by Git. Automatic signing is already enabled.
4. Connect the phone by cable, accept the Trust prompt, and enable Developer Mode when prompted.
5. Select the phone in Xcode and press Run.
6. If required, trust your developer account under Settings → General → VPN & Device Management on the phone.

A free Apple Account works. Free signing expires after seven days; install again from Xcode to renew it.
Keep the same team and bundle identifier when updating, and do not delete the app if you want to keep its records.

</details>
