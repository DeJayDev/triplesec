# Triplesec

Triple-press a mouse side button to lock the screen.

A tiny macOS background agent for the lid-closed-but-still-unlocked problem: a Mac on power with external monitors stays awake when you close the lid, so walking away leaves it unlocked. Press a side button three times and it locks.

## How it works

- Background agent — no dock icon, no window, no menu bar item
- Watches mouse button events via a `CGEvent` tap (`listenOnly`, so back/forward still work)
- Three presses of the **same side button**, each within 0.5s of the previous, triggers a lock
- Locks via `SACLockScreenImmediate` from the private `login.framework` (`CGSession -suspend` was removed in macOS 26)
- Mouse only — never taps the keyboard, writes nothing to disk

## Requirements

- macOS 26.5+
- Xcode
- A mouse with side buttons

## Build

```sh
xcodebuild -project Triplesec.xcodeproj -scheme Triplesec -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application: <YOUR NAME> (<TEAM ID>)" \
  DEVELOPMENT_TEAM=<TEAM ID>
```

Xcode injects `get-task-allow` even for Release. Strip it so the app carries no entitlements:

```sh
codesign --force --options runtime --timestamp \
  -s "Developer ID Application: <YOUR NAME> (<TEAM ID>)" \
  build/Build/Products/Release/Triplesec.app
```

## Install

Install to `/Applications` — the login item and Input Monitoring grant are tied to this path:

```sh
ditto build/Build/Products/Release/Triplesec.app /Applications/Triplesec.app
open /Applications/Triplesec.app
```

On first launch it requests **Input Monitoring** and opens the Settings pane. Grant access, then relaunch — the tap only arms once permission is granted.

Changing the signing certificate invalidates the old Input Monitoring grant. Re-approve in System Settings if that happens.

## Autostart

Registers itself as a login item via `SMAppService` on launch. Don't move or delete `/Applications/Triplesec.app`; the login item points there.

## Configuration

In `handle(_:_:)` in `Triplesec/TriplesecApp.swift`:

| Setting | Default | Notes |
| --- | --- | --- |
| Which button | `button >= 3` | 0=left, 1=right, 2=middle, 3+=side (3=back, 4=forward). Pin with e.g. `button == 4`. |
| Press count | `count >= 3` | |
| Inter-press window | `0.5` s | Max gap between consecutive presses |

## Notes

- Uses a private framework symbol (`SACLockScreenImmediate`). Fine for personal use; not App Store material.
- Build is signed but not notarized. For another Mac without Gatekeeper friction: notarize and staple (`xcrun notarytool submit` + `xcrun stapler staple`).
- Also set System Settings → Lock Screen → require password immediately after sleep / screen saver. The button is convenience; that setting is the real backstop.
