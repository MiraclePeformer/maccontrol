# MacControl

A lightweight macOS **menu bar control center**. Click the slider icon in the menu
bar and a popover gives you quick control over brightness, audio, your default
browser, and a mouse jiggler — all in one place, updating live while it's open.

Native Swift + SwiftUI, no dependencies. Universal binary (Apple Silicon + Intel),
menu-bar only (no Dock icon).

## Features

- **Displays** — brightness per screen, including software dimming for external monitors
- **Audio** — volume, mute, and output-device switching
- **System** — set the default browser
- **Mouse Jiggler** — keeps your Mac awake at a configurable interval (1–3600s)
- **Launch at login** — optional, via `SMAppService`

## Requirements

- macOS 13.0 or later
- Xcode command line tools (`swiftc`, `lipo`, `hdiutil`, `codesign`)

## Build

```bash
./build.sh
```

This compiles a universal binary, assembles `MacControl.app`, ad-hoc code-signs it,
and packages a drag-to-install installer at `build/MacControl.dmg`.

## Install

Open `build/MacControl.dmg` and drag **MacControl** to Applications.

Because the app is **ad-hoc signed**, the first launch may be blocked by Gatekeeper.
If so, right-click the app → **Open**, or allow it under
*System Settings → Privacy & Security*.

## Accessibility permission (for the jiggler)

The mouse jiggler moves the cursor, which requires **Accessibility** permission:

*System Settings → Privacy & Security → Accessibility* → turn on **MacControl**,
then quit and relaunch the app.

> **Heads-up for rebuilds:** ad-hoc signed apps get a new identity on every build, so
> macOS drops the previously granted Accessibility permission. After rebuilding you
> may need to remove the old **MacControl** entry (`–`) and re-add the new one (`+`).
> Signing with a stable Developer ID certificate avoids this.

## Project layout

```
Sources/          Swift source
  main.swift            app delegate, menu bar item, popover
  MenuState.swift       observable state shared with the SwiftUI panel
  PanelView.swift       the SwiftUI control panel
  AudioController.swift    volume / mute / output device (CoreAudio)
  DisplayController.swift  per-display brightness
  BrowserController.swift  default browser
  Jiggler.swift            cursor jiggle loop
Resources/        app icon
tools/            icon generation helpers
Info.plist        app bundle metadata
build.sh          build + package into .dmg
```

## License

No license specified yet — all rights reserved by default. Add a `LICENSE` file if
you want to make reuse terms explicit.

Made by metr0.
