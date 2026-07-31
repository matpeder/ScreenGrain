# Input-monitoring screenshot workaround research (macOS 14+)

## Decision

For an opt-in screenshot workaround, use a Core Graphics event tap created with
`.listenOnly`, not an `NSEvent` global monitor. The tap can observe only the
keyboard and pointer events needed to recognise the standard screenshot
shortcuts, while returning every event unchanged. This makes **Input
Monitoring** the only additional privacy permission required by this approach;
it does not need Accessibility or Screen Recording access.

It is necessarily a best-effort workaround for the system screenshot UI. It
can hide ScreenGrain when the user invokes the standard screenshot shortcuts;
it cannot detect arbitrary screen recordings or shares started by Google Meet,
Slack, or another process.

## Permission flow

`CGPreflightListenEventAccess()` checks whether the app already has event
listening access. `CGRequestListenEventAccess()` requests that access when it
is absent, potentially prompting the user. Both are public Core Graphics APIs
available from macOS 10.15, so they are available on ScreenGrain's macOS 14
target.

Call the request function only after the user turns on **Hide in captures**.
If the request is denied, keep the preference off and explain that Input
Monitoring is needed for the screenshot shortcut workaround. Do not request
the permission at launch or while the preference is off.

Apple calls this scope **Input Monitoring**. It grants monitoring of keyboard,
mouse, and trackpad input while another app is active; users manage it in
System Settings > Privacy & Security > Input Monitoring. It is distinct from
Screen Recording and Accessibility.

Sources:

- [CGPreflightListenEventAccess](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess%28%29)
- [CGRequestListenEventAccess](https://developer.apple.com/documentation/coregraphics/cgrequestlisteneventaccess%28%29)
- Xcode 26 macOS SDK `CoreGraphics.framework/Headers/CGEvent.h`, lines
  398–402: both APIs are `API_AVAILABLE(macos(10.15))`; the request may prompt.
- [Control access to input monitoring on Mac](https://support.apple.com/guide/mac-help/control-access-to-input-monitoring-on-mac-mchl4cedafb6/mac)

## Event tap choice and lifecycle

Create `CGEvent.tapCreate` at `.cgSessionEventTap`, using `.headInsertEventTap`
and `.listenOnly`, with an event mask restricted to the events ScreenGrain
uses. `.listenOnly` is explicitly passive: the callback must return the
original event, so ScreenGrain cannot consume or alter `Command-Shift-3`,
`Command-Shift-4`, `Command-Shift-5`, Space, Escape, or clicks. Add the tap's
run-loop source while the setting is enabled; invalidate/remove the source and
release the port when it is disabled or the application terminates. Handle a
nil tap as a denied/unavailable state even after preflight.

The callback runs on the run loop that owns its source. Keep it constant-time:
recognise the intended shortcut/state, schedule overlay visibility changes on
the main actor if necessary, and return the event without blocking. Also
handle `tapDisabledByTimeout` and `tapDisabledByUserInput` by re-enabling a
still-authorised tap or marking the workaround unavailable.

`NSEvent.addGlobalMonitorForEvents` is not the right implementation: it is
observer-only and asynchronous, but Apple documents that key-event monitoring
through it requires Accessibility/trusted-accessibility permission. It also
does not receive events sent to the calling app. That would ask for a broader,
unnecessary permission.

Sources:

- [CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate%28tap%3Aplace%3Aoptions%3Aeventsofinterest%3Acallback%3Auserinfo%3A%29)
- [CGEventTapOptions.listenOnly](https://developer.apple.com/documentation/coregraphics/cgeventtapoptions/listenonly)
- [NSEvent.addGlobalMonitorForEvents](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents%28matching%3Ahandler%3A%29)

## Screenshot state and restoration

macOS exposes no public notification that the system screenshot UI has opened,
closed, cancelled, or completed a capture. There is likewise no public
signal for another app beginning a screen recording or screen share. An event
tap can therefore react to recognised user input but cannot prove a capture
occurred or that it has ended.

For `Command-Shift-4`, hide overlays as soon as the shortcut is observed, keep
them hidden while the system picker is active, and restore on the next capture
click or Escape. Schedule restoration after the capture click with a short,
one-shot delay so the screenshot service has consumed the click; cancel that
work when the state changes. This is a bounded cleanup mechanism, not an idle
poll or permanent timer. `Command-Shift-3` is inherently less certain because
it captures immediately; a passive listener cannot delay it. `Command-Shift-5`
can leave the screenshot toolbar open indefinitely, so it should either remain
hidden until Escape/a capture action or be explicitly outside the initial
workaround's supported scope.

The product copy must say **Hide in screenshots** rather than claiming to
exclude all captures or shares. Input Monitoring can make native
`Command-Shift-4`, Space window picking workable; it cannot promise clean
content in Meet, Slack, or arbitrary recording software.

Related capture-exclusion limits are documented in
[capture-exclusion-research.md](capture-exclusion-research.md).
