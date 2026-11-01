# BarMod

A Windows-style tray popup for the macOS menu bar. Click BarMod's chevron and a
panel lists every icon macOS hid because the menu bar ran out of room. Click an
icon to open its real menu.

## Install

```sh
brew install --cask jasurito/tap/barmod
```

Then open BarMod and allow it under System Settings → Privacy & Security →
Accessibility. To start it at login, add it under System Settings → General →
Login Items.

Requires macOS 14 or later. Tested on macOS 26.6 with Apple Silicon. Intel builds
and macOS 27, which draws the menu bar differently, are untested.

Update with `brew upgrade --cask barmod`, remove with
`brew uninstall --cask barmod`.

The app is open source but not notarized by Apple (no paid developer account), so
the cask removes the macOS quarantine flag after install. Without that, macOS
would refuse the first launch. If you download the zip from
[Releases](https://github.com/Jasurito/BarMod/releases) manually, try opening the
app once, then allow it in System Settings → Privacy & Security → Open Anyway.

## Permissions

**Accessibility** is the only permission. BarMod uses it to find icons and open
their menus. It does not capture your screen and has no network code.

## Build from source

Needs Xcode Command Line Tools, not Xcode.

```sh
./Scripts/run.sh    # build, sign, restart
./Scripts/test.sh   # unit tests
```

The app is written to `build/BarMod.app`.

macOS ties the Accessibility grant to the signing identity.
`Scripts/make-signing-identity.sh` creates a self-signed one in a private keychain
under `.signing/`, so the grant survives rebuilds. Keep that folder out of version
control.

## Releasing

Push a version tag:

```sh
git tag v1.2.0 && git push origin v1.2.0
```

GitHub Actions tests, builds the universal app, publishes the release, and updates
the cask in [Jasurito/homebrew-tap](https://github.com/Jasurito/homebrew-tap). See
`.github/workflows/release.yml`.

Releases are signed with the identity in the repo's secrets. The workflow fails if
the certificate changes, because a new one makes every user allow Accessibility
again.

## How it works

- **Find:** on macOS 26 Control Center owns every status item window, so window
  owners do not identify apps. BarMod reads each app's `AXExtrasMenuBar` instead.
- **Decide what is hidden:** an icon is hidden if it sits under the notch, under
  the frontmost app's menus, or off screen. See `MenuBarLayout.hides`.
- **Open:** `AXPress` on the icon. The menu opens at the icon's real position.
- **Draw:** the popup shows app icons, and SF Symbols for Control Center items.
  BarMod does not show real menu bar glyphs: on macOS 26.6 ScreenCaptureKit and
  SkyLight capture of status item windows both returned blank images.
- **Stay visible:** new status items land nearest the notch, so BarMod seeds
  `NSStatusItem Preferred Position` to start near the right edge.

## Diagnostics

The dump must go through `open`, so macOS checks BarMod's permissions and not
the terminal's:

```sh
open -n -W build/BarMod.app --args --dump /tmp/barmod-dump.txt
```

Two more modes act on the real menu bar, so they open real menus:

```sh
# Press an icon by name and report where its menu appeared
open -n -W build/BarMod.app --args --press Raycast /tmp/barmod-press.txt
# List the open popup's buttons, optionally pressing one
open -n -W build/BarMod.app --args --panel /tmp/barmod-panel.txt Raycast
```

Runtime log: `~/Library/Logs/BarMod/barmod.log`. Press result `-25204` is normal:
the app stops answering while its menu is open.

## License

MIT
