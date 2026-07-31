# Triplesec

Triple-press a mouse side button to lock your Mac.

For one situation: a MacBook with the lid closed and an external display
attached keeps the screen awake and unlocked. Triplesec is invisible — no
window, Dock icon, or menu bar item — runs at login, and writes nothing to disk.

## Gesture

- 3 presses of any one side button, ≤ 0.5s apart
- Back/forward keep working; left, right, and middle clicks are ignored

## Requirements

- macOS 26.5+
- A mouse with side buttons
- Xcode and a Developer ID Application certificate

## Caveats

- Locks via a private macOS function: not App Store-compatible, and may break on
  a future macOS update.
- Needs Input Monitoring permission.

## Install

No prebuilt release; build from source. Replace `<YOUR NAME>` and `<TEAM ID>`.

```sh
xcodebuild -project Triplesec.xcodeproj -scheme Triplesec -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application: <YOUR NAME> (<TEAM ID>)" \
  DEVELOPMENT_TEAM=<TEAM ID>
```

Sign without Xcode's development entitlement:

```sh
codesign --force --options runtime --timestamp \
  -s "Developer ID Application: <YOUR NAME> (<TEAM ID>)" \
  build/Build/Products/Release/Triplesec.app
```

Install and launch:

```sh
ditto build/Build/Products/Release/Triplesec.app /Applications/Triplesec.app
open /Applications/Triplesec.app
```

Then:

1. Grant **Input Monitoring** when prompted, and reopen the app.
2. If prompted, enable the login item in **System Settings → General → Login
   Items**.

Keep the app in `/Applications` — the permission and login-item registration
bind to that copy. A different signing certificate counts as a new app and
re-prompts for Input Monitoring.

## Configure

Triplesec has no settings screen. Edit `LockGesture` in
`Triplesec/TriplesecApp.swift`, then rebuild and reinstall.

| Constant | Default | Controls |
| --- | --- | --- |
| `minimumButtonNumber` | `3` (any side button) | Which side button |
| `requiredPresses` | `3` | Press count |
| `maximumInterval` | `0.5` | Max seconds between presses |

Button numbers: 0 left, 1 right, 2 middle, 3+ side.

## Uninstall

1. **System Settings → General → Login Items** → turn off Triplesec.
2. Quit Triplesec in Activity Monitor.
3. Delete `/Applications/Triplesec.app`.

## Security

Triplesec is a convenience and must be coupled with good security posture.

Ensure that **System Settings → Lock Screen → Require password after screen
saver begins or display is turned off** is set to **Immediately**.

## How it works

Installs a listen-only `CGEvent` tap on side-button mouse-down, so clicks reach
their normal target. On the gesture, calls `SACLockScreenImmediate` from the
private `login.framework`. Registers the login item via `SMAppService`.

Signed but not notarized, so other Macs show a Gatekeeper warning. To remove it,
notarize and staple: `xcrun notarytool submit`, then `xcrun stapler staple`.
