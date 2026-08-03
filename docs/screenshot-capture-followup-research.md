# Screenshot capture follow-up — 2026-08-03

## Conclusion

There is no public macOS API that lets an AppKit window opt itself out of the
system Screenshot UI, its screenshots, or another app's screen share. A
shortcut observer can make a best-effort attempt to order the overlay out
before a screenshot shortcut reaches the system, but it cannot provide a
reliable capture-exclusion guarantee.

## Relevant public APIs

- A Core Graphics event tap may be inserted at the head of the *event-tap*
  list, and a `listenOnly` tap is a passive listener. This supports observing
  Command-Shift-3/4/5 without changing their events. It does **not** document
  an ordering guarantee relative to Screenshot's private shortcut handling or
  a WindowServer compositing transaction. [CGEventTapPlacement](https://developer.apple.com/documentation/coregraphics/cgeventtapplacement), [listenOnly](https://developer.apple.com/documentation/coregraphics/cgeventtapoptions/listenonly), [tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate%28tap%3Aplace%3Aoptions%3Aeventsofinterest%3Acallback%3Auserinfo%3A%29)
- `CGPreflightListenEventAccess()` checks and
  `CGRequestListenEventAccess()` requests event-listening access. However, the
  Xcode 26.1 SDK's `CGEvent.h` says a session event tap receives key events
  only when the process has **Accessibility** (“assistive devices”) access;
  without it, the key-event bits are cleared and tap creation can return
  `nil`. AppKit gives the same requirement for global key monitoring.
  `AXIsProcessTrustedWithOptions` is the public API that checks this trust and
  can ask the system to prompt the user. Therefore an Input-Monitoring-only
  preference is not sufficient evidence that the monitor receives shortcuts.
  [CGPreflightListenEventAccess](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess%28%29), [CGRequestListenEventAccess](https://developer.apple.com/documentation/coregraphics/cgrequestlisteneventaccess%28%29), [AppKit global event monitoring](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents%28matching%3Ahandler%3A%29), [Accessibility trust check](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)
- `NSWindow.SharingType.none` must not be used as the fix. The current AppKit
  documentation describes it as a **legacy constant that macOS no longer
  uses**. The older SDK header still describes the historical sharing meaning,
  which conflicts with the current API reference; the current reference is the
  appropriate compatibility contract. [NSWindow.SharingType](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum)
- ScreenCaptureKit's `SCContentFilter` can exclude windows, but only from an
  `SCStream` created and controlled by the caller. It cannot alter the macOS
  Screenshot service, Slack, Meet, or another app's stream. Using it here
  would mean ScreenGrain captures the display itself and requires Screen
  Recording permission. [SCContentFilter](https://developer.apple.com/documentation/screencapturekit/sccontentfilter), [excluding windows](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init%28display%3Aexcludingwindows%3A%29), [Apple capture guide](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)

## Likely cause of the observed failure

The implementation already calls its capture callback directly from the event
tap callback; it is not currently delayed through `DispatchQueue.main.async`.
But it requests only Input Monitoring, while its session event tap observes
key-down events. The documented Accessibility requirement is therefore the
most likely reason the shortcut callback never runs. If grain remains visible
after Command-Shift-4 has opened the selector, validate Accessibility trust
and tap creation before investigating the restoration timing.

If the tap does receive the shortcut and orders the panels out, Command-Shift-3
can still race: it captures immediately, and there is no public “screenshot is
about to capture” or “screenshot finished” notification. Command-Shift-4/5
have more time, but no public API confirms that WindowServer has committed the
overlay's removal before the system picks a window or snapshots the display.

## Supported recommendation

1. Keep `Hide in Captures` explicitly opt-in, but ask for **Accessibility**
   only when it is enabled. Explain that it is required solely to observe the
   native screenshot shortcut; do not claim Input Monitoring alone is enough.
   `AXIsProcessTrustedWithOptions` prompts asynchronously, so keep the setting
   off until the user has granted access and enabled it again.
2. Add an observable monitor health state: distinguish *Accessibility absent*,
   *tap creation failed*, *tap disabled*, and *last recognised shortcut time*.
   This makes a permission/setup failure diagnosable instead of silently
   claiming capture hiding is active.
3. On a recognised shortcut, synchronously order all existing overlay panels
   out in the tap callback before returning the event. Do not dispatch that
   operation asynchronously, do not wait for display reconciliation, and do
   not consume or modify the screenshot event. Reconcile/recreate panels only
   after capture restoration.
4. Test Command-Shift-4 window picking manually after the health state reports
   an observed shortcut. This is the only native workflow with a useful
   best-effort window before capture. Treat Command-Shift-3 and Command-Shift-5
   as best effort, and do not promise Slack/Meet/general recording coverage.

An active event tap does not solve this: it adds more intrusive privileges and
could suppress the native screenshot shortcut, while still lacking a public
capture-service or compositor completion contract.
