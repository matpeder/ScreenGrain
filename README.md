# ScreenGrain

ScreenGrain is a deliberately small, menu-bar-only macOS utility that places
subtle static noise or film grain over every connected display. It makes smooth
digital surfaces feel a little more tactile without capturing the screen,
animating pixels, or requesting privacy permissions.

The texture is generated once from a saved seed and tiled across passive AppKit
overlay windows. There are no timers, display links, render loops, background
services, third-party dependencies, networking, or analytics.

## Requirements

- Apple Silicon Mac
- macOS 14 Sonoma or later
- Xcode 16 or later to build

## Build and run

Open `ScreenGrain.xcodeproj`, select the `ScreenGrain` scheme and **My Mac**,
then run.

The equivalent command-line build is:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project ScreenGrain.xcodeproj \
  -scheme ScreenGrain \
  -configuration Release \
  -derivedDataPath /tmp/ScreenGrain-Release \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The unsigned app will be at:

```text
/tmp/ScreenGrain-Release/Build/Products/Release/ScreenGrain.app
```

A locally built app normally launches directly. The command above explicitly
disables signing, so that artifact cannot register with `SMAppService`; to test
**Launch at Login**, build with signing enabled in Xcode and move that app to
`/Applications`. If macOS quarantines an unsigned copy downloaded from
elsewhere, use **Open Anyway** in System Settings → Privacy & Security.
ScreenGrain v1 does not include Developer ID signing, notarization, an updater,
or an installer.

Run the tests with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project ScreenGrain.xcodeproj \
  -scheme ScreenGrain \
  -configuration Debug \
  -derivedDataPath /tmp/ScreenGrain-DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Controls

Click the dotted-circle menu-bar icon to open the control panel.

- **Enabled** immediately shows or hides every overlay.
- **Mode** switches between fine independent Noise and softly correlated Film
  Grain.
- **Opacity**, **Grain size**, and **Intensity** tune the effect. Opacity and
  intensity both cover the full 0–100% range.
- **Color** switches between monochrome and visibly coloured grain.
- **Re-roll** creates and saves a new deterministic seed.
- **Launch at Login** uses `SMAppService.mainApp`.
- **Quit ScreenGrain** removes every overlay immediately.

Settings and the seed are stored in `UserDefaults` and restored on the next
launch.

## Architecture

- `AppModel` owns settings, persistence, login-item changes, and update
  dispatch.
- `OverlayCoordinator` re-reads `NSScreen.screens` and reconciles one
  `OverlayPanel` per stable `CGDirectDisplayID` on launch, display changes,
  wake, and active-Space changes. It combines each display's reported pixel
  density with its active backing scale so a grain-size setting stays physically
  consistent across mixed-density and macOS-scaled displays.
- Each overlay is a borderless, nonactivating, click-through `NSPanel` at the
  lowest level above ordinary pop-up menus. Public collection behaviours let
  it join all Spaces, eligible full-screen Spaces, and Stage Manager app sets.
- `TextureGenerator` uses SplitMix64 and a 512×512 premultiplied RGBA tile.
  Noise uses independent samples; Film Grain blends a fine toroidal 3×3
  correlation pass with a softer second scale. Generation is deterministic
  and event-driven.
- The control panel is a native AppKit status item and popover. There is no
  SwiftUI, Metal, screen capture, or continuous renderer.

## Capture and other limitations

**Show in Screenshot UI** is off by default. When it is off, ScreenGrain hides
while macOS's Screenshot interface is open and restores when it closes. This
keeps the overlay out of the Space-to-select-window workflow for screenshots.
It is an event-driven convenience, not general capture exclusion: it cannot
guarantee exclusion from direct captures that complete before the interface is
observed.

macOS provides no supported app-side way to exclude an arbitrary AppKit overlay
from another application's recording or screen share. Therefore ScreenGrain
cannot reliably hide itself from Slack, Google Meet, or other third-party
sharing apps, and it requests no Screen Recording permission. Apple's
`NSWindow.SharingType.none` is a legacy value that macOS no longer uses for
capture exclusion; ScreenGrain does not rely on it.

An independent translucent overlay cannot blend against pixels owned by other
applications. Balanced light and dark samples remain visible over both light
and dark backgrounds, but stronger settings can slightly influence perceived
luminance.

Lock Screen, authentication windows, DRM-protected surfaces, protected system
UI, and windows above ScreenGrain's overlay level are best-effort limitations.
The grain intentionally covers ordinary menus and popovers. Full-screen and
Stage Manager behaviour uses public APIs but should be checked on each target
macOS release. Launch at Login can require approval in System Settings and is
most reliable after moving the app to `/Applications`.

## Validation checklist

Automated tests cover deterministic output, re-rolling, valid premultiplied
pixel bounds, approximate neutrality, distinct spatial structure between
modes, settings persistence, first-launch defaults, and legacy-settings
migration.

Complete these GUI checks on the Macs and display arrangements you rely on:

- [ ] Launch, menu-bar presence, and Quit
- [ ] Enable/disable and every control updating all displays
- [ ] Clicks and scrolling pass through the entire overlay
- [ ] Overlay never becomes key and never steals focus
- [ ] One display and multiple displays
- [ ] Mixed Retina/non-Retina scaling and mirrored displays
- [ ] Connect, disconnect, rearrange, and change display resolution
- [ ] Ordinary full-screen apps and multiple Spaces
- [ ] Stage Manager
- [ ] Sleep and wake
- [ ] Relaunch and state restoration
- [ ] Launch at Login from an app in `/Applications`
- [ ] Light, dark, white, and black backgrounds
- [ ] Screenshot UI and Space-to-select-window behaviour with **Show in Screenshot UI** on and off
- [ ] Screen recording and third-party sharing behaviour (a known platform limitation)
- [ ] Idle CPU, GPU, and memory in Activity Monitor

During development, the Release build was observed at 0.0% sampled idle CPU and
about 49 MB RSS with two overlay windows on a 2560×1440 display and a 1512×982
display. This is an informal single-machine observation, not a performance
guarantee; window-server backing costs vary by display setup.

## License

ScreenGrain is available under the [MIT License](LICENSE).
