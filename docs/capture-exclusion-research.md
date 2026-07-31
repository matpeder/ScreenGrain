# Capture exclusion research (macOS 14+)

## Conclusion

There is no supported, reliable, app-side switch that makes an arbitrary AppKit
overlay disappear from the system screenshot UI, another application's screen
recording, or a third-party screen share.

`NSWindow.sharingType = .none` is not a viable implementation. Although the
property remains available on macOS (the current SDK declares it available from
macOS 10.5), Apple now documents `.none` as a legacy value that macOS no longer
uses and explicitly says not to use it to hide or omit captured content.

Sources:

- [NSWindow.SharingType.none](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none): Apple calls it a legacy constant and says it is not for hiding captured content.
- [NSWindow.sharingType](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.property): the property expresses the level of other-process access to a window's content; it is not a capture-exclusion contract.
- Xcode 26 macOS SDK `AppKit.framework/Headers/NSWindow.h`, lines 86–89 and 520–522: declares `NSWindowSharingType` and notes that `.none` can prevent system-service participation. This confirms API availability, not current capture reliability.

## Scope of ScreenCaptureKit

ScreenCaptureKit can exclude windows or applications **only from a capture that
the calling app itself creates**. Its content filters are supplied to that
app's `SCStream`; they cannot alter the macOS screenshot service or capture
sessions owned by Slack, Google Meet, or another process. Adopting it here
would instead mean ScreenGrain performs capture itself, which needs Screen
Recording permission and is outside this app's passive-overlay design.

Sources:

- [SCContentFilter.init(display:excludingWindows:)](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init%28display%3Aexcludingwindows%3A%29): creates a filter for the caller's display capture.
- [Capturing screen content in macOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos): Apple's sample requests Screen Recording permission before the sample begins capture, then applies its own filter to its own stream.

## Screenshot window picker

Public window-list APIs only report windows; they do not configure the system
screenshot UI or exclude a window from its Space-to-select-window mode.
`CGWindowListCopyWindowInfo` can list windows in front-to-back order, but it
has no counterpart for changing the screenshot picker. `ignoresMouseEvents`
similarly affects ordinary AppKit mouse delivery, not the separate system
screenshot selection service.

Sources:

- [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo%28_%3A_%3A%29): returns window information for the current user session.
- [CGWindowListOption.optionOnScreenOnly](https://developer.apple.com/documentation/coregraphics/cgwindowlistoption/optiononscreenonly): lists onscreen windows in front-to-back order.

## Product implication

Do not promise a general “exclude from screenshots and screen sharing” setting.
For a passive, permission-free v1, the reliable control remains the existing
manual Enabled toggle. Detecting the global screenshot keyboard shortcut would
require monitoring input outside ScreenGrain and still would not detect every
capture path; it would also fail to guarantee a clean capture. No public,
documented notification identifies third-party screen-share or recording start
events for ScreenGrain to react to.

The system window-picker problem is therefore also not safely fixable through
public AppKit APIs. Any workaround based on temporarily hiding the overlay
would be heuristic, potentially visible to the user, and cannot be triggered
reliably without additional privacy-sensitive input monitoring.
