# Triplesec

Lock your Mac by pressing a mouse side button three times.

Triplesec is for a very specific annoyance: you use a MacBook with the lid
closed and an external display attached, then get up and walk away. Because the
Mac is still driving that display, closing the lid did not put it to sleep—and
the screen you thought you had left safely behind is still unlocked.

With Triplesec running, press either side button on your mouse three times in
quick succession. Your Mac locks. That is the whole app.

Your back and forward buttons still work normally. Triplesec only listens for
the three presses; it does not intercept them or do anything with your
keyboard.

## What to expect

Triplesec is deliberately invisible. It has no window, Dock icon, or menu bar
item. The first time you open it, macOS asks for **Input Monitoring** permission.
Grant access, open Triplesec again, and it will run in the background and start
automatically when you log in. If macOS says the login item needs approval,
enable Triplesec in **System Settings → General → Login Items**.

The lock gesture is:

- three presses of the same side button
- no more than half a second between presses
- any side button; left, right, and middle clicks are ignored

This is a small personal utility, not a polished downloadable app. There is no
prebuilt release yet, so trying it currently means building it from source.

## Before you install it

You will need:

- macOS 26.5 or later
- a mouse with side buttons
- Xcode and a Developer ID Application signing certificate

Triplesec uses a private macOS function to lock the screen. That makes it fine
for a personal build, but unsuitable for the App Store and more likely to break
after a future macOS update. If you would rather not give a background utility
Input Monitoring access or run code that relies on a private system framework,
this app is not a good fit for you.

## Build and install

Replace the certificate name and team ID below with your own:

```sh
xcodebuild -project Triplesec.xcodeproj -scheme Triplesec -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application: <YOUR NAME> (<TEAM ID>)" \
  DEVELOPMENT_TEAM=<TEAM ID>
```

Then sign the finished app without Xcode's development entitlement:

```sh
codesign --force --options runtime --timestamp \
  -s "Developer ID Application: <YOUR NAME> (<TEAM ID>)" \
  build/Build/Products/Release/Triplesec.app
```

Copy it to `/Applications` and open it:

```sh
ditto build/Build/Products/Release/Triplesec.app /Applications/Triplesec.app
open /Applications/Triplesec.app
```

When macOS opens the Input Monitoring settings, enable Triplesec and then open
the app once more. Keep it in `/Applications`: both the permission and its
login-item registration are associated with that installed copy.

If you rebuild with a different signing certificate, macOS will treat it as a
different app and ask you to grant Input Monitoring again.

## Change the gesture

There is no settings screen. The three parts of the gesture are constants on
`LockGesture` in `Triplesec/TriplesecApp.swift`:

| Behavior | Default | What to change |
| --- | --- | --- |
| Side button | Any (`minimumButtonNumber = 3`) | Change the minimum button number |
| Number of presses | Three (`requiredPresses = 3`) | Change the required press count |
| Time between presses | 0.5 seconds | Change `maximumInterval` |

Mouse button numbers are 0 for left, 1 for right, 2 for middle, and 3 or higher
for side buttons. After changing the gesture, rebuild and reinstall the app.

## Remove it

Turn off Triplesec in **System Settings → General → Login Items**, quit the
running process in Activity Monitor, and delete `/Applications/Triplesec.app`.

## A note about screen security

Triplesec is a convenient lock button, not a replacement for macOS security
settings. Set **System Settings → Lock Screen → Require password after screen
saver begins or display is turned off** to **Immediately**. That setting is what
protects your Mac when you forget the gesture.

<details>
<summary>Implementation notes</summary>

Triplesec installs a listen-only `CGEvent` tap for side-button mouse-down events,
so the original clicks continue to their normal destination. Once it recognizes
the gesture, it calls `SACLockScreenImmediate` from the private `login.framework`.
It registers the installed app as a login item with `SMAppService` and does not
write any data to disk.

The build is signed but not notarized. To distribute it to another Mac without
the usual Gatekeeper warning, notarize and staple it with
`xcrun notarytool submit` and `xcrun stapler staple`.

</details>
