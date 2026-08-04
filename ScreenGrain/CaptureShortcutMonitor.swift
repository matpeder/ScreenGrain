import ApplicationServices
import CoreGraphics
import Foundation

enum CaptureShortcutKind: Equatable {
    case immediateScreenshot
    case interactiveScreenshot
    case captureToolbar
}

final class CaptureShortcutMonitor {
    enum StartResult {
        case started
        case permissionsRequired
        case unavailable
    }

    var onCaptureShortcut: ((CaptureShortcutKind) -> Void)?
    var onCaptureShortcutPreparation: (() -> Void)?
    var onInteractiveCaptureFinished: (() -> Void)?
    var onCaptureCancelled: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var activeShortcut: CaptureShortcutKind?
    private var isPreparingScreenshotShortcut = false

    func start(requestingPermission: Bool) -> StartResult {
        guard eventTap == nil else { return .started }

        let canListen = CGPreflightListenEventAccess()
        let isAccessibilityTrusted = AXIsProcessTrusted()
        if !canListen || !isAccessibilityTrusted {
            guard requestingPermission else { return .permissionsRequired }

            if !canListen {
                CGRequestListenEventAccess()
            }
            if !isAccessibilityTrusted {
                AXIsProcessTrustedWithOptions([
                    kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true,
                ] as CFDictionary)
            }
            return .permissionsRequired
        }

        let eventMask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return .unavailable
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        runLoopSource = source
        return .started
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        activeShortcut = nil
        isPreparingScreenshotShortcut = false
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<CaptureShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.handle(type: type, event: event)
        return Unmanaged.passUnretained(event)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        case .keyDown:
            handleKeyDown(event)
        case .flagsChanged:
            handleFlagsChanged(event)
        case .leftMouseUp:
            if activeShortcut == .interactiveScreenshot {
                activeShortcut = nil
                onInteractiveCaptureFinished?()
            }
        default:
            break
        }
    }

    private func handleKeyDown(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == 53, activeShortcut != nil {
            activeShortcut = nil
            onCaptureCancelled?()
            return
        }

        guard let shortcut = Self.screenshotShortcut(
            keyCode: keyCode,
            flags: event.flags
        ) else {
            return
        }

        activeShortcut = shortcut
        isPreparingScreenshotShortcut = false
        onCaptureShortcut?(shortcut)
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let isHoldingScreenshotModifiers = Self.hasScreenshotModifiers(event.flags)

        if isHoldingScreenshotModifiers, activeShortcut == nil, !isPreparingScreenshotShortcut {
            isPreparingScreenshotShortcut = true
            onCaptureShortcutPreparation?()
        } else if !isHoldingScreenshotModifiers, activeShortcut == nil, isPreparingScreenshotShortcut {
            isPreparingScreenshotShortcut = false
            onCaptureCancelled?()
        }
    }

    static func screenshotShortcut(keyCode: Int64, flags: CGEventFlags) -> CaptureShortcutKind? {
        guard hasScreenshotModifiers(flags) else { return nil }

        switch keyCode {
        case 20: return .immediateScreenshot
        case 21: return .interactiveScreenshot
        case 23: return .captureToolbar
        default: return nil
        }
    }

    static func hasScreenshotModifiers(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskCommand) && flags.contains(.maskShift)
    }
}
