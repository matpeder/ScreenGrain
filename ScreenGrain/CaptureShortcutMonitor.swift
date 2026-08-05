import AppKit
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
        case started(Strategy)
        case accessibilityRequired(inputMonitoringGranted: Bool)
        case unavailable
    }

    enum Strategy {
        case eventTapAndGlobalMonitor
        case globalMonitor
    }

    var onCaptureShortcut: ((CaptureShortcutKind) -> Void)?
    var onCaptureShortcutPreparation: (() -> Void)?
    var onInteractiveCaptureFinished: (() -> Void)?
    var onCaptureCancelled: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var activeShortcut: CaptureShortcutKind?
    private var isPreparingScreenshotShortcut = false

    func start(requestingPermission: Bool) -> StartResult {
        if eventTap != nil, globalMonitor != nil {
            return .started(.eventTapAndGlobalMonitor)
        }
        if globalMonitor != nil {
            return .started(.globalMonitor)
        }

        let canListen = CGPreflightListenEventAccess()
        let isAccessibilityTrusted = AXIsProcessTrusted()
        if !isAccessibilityTrusted {
            if requestingPermission {
                AXIsProcessTrustedWithOptions([
                    kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true,
                ] as CFDictionary)
            }
            if !canListen, requestingPermission {
                CGRequestListenEventAccess()
            }
            return .accessibilityRequired(inputMonitoringGranted: canListen)
        }

        // This public AppKit monitor backs up the Quartz event tap when it is
        // denied or temporarily unavailable. It observes the same shortcut
        // without ever altering the original event.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .leftMouseUp, .flagsChanged]
        ) { [weak self] event in
            self?.handleGlobalEvent(event)
        }

        guard globalMonitor != nil else { return .unavailable }

        if !canListen, requestingPermission {
            CGRequestListenEventAccess()
        }

        guard canListen else { return .started(.globalMonitor) }

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
        ) else { return .started(.globalMonitor) }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        runLoopSource = source
        return .started(.eventTapAndGlobalMonitor)
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
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        globalMonitor = nil
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
            finishInteractiveCapture()
        default:
            break
        }
    }

    private func handleGlobalEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            handleKeyDown(keyCode: Int64(event.keyCode), flags: event.cgFlags)
        case .flagsChanged:
            handleFlagsChanged(flags: event.cgFlags)
        case .leftMouseUp:
            finishInteractiveCapture()
        default:
            break
        }
    }

    private func handleKeyDown(_ event: CGEvent) {
        handleKeyDown(
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            flags: event.flags
        )
    }

    private func handleKeyDown(keyCode: Int64, flags: CGEventFlags) {
        if keyCode == 53, activeShortcut != nil {
            activeShortcut = nil
            onCaptureCancelled?()
            return
        }

        guard let shortcut = Self.screenshotShortcut(
            keyCode: keyCode,
            flags: flags
        ) else {
            return
        }

        activeShortcut = shortcut
        isPreparingScreenshotShortcut = false
        onCaptureShortcut?(shortcut)
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        handleFlagsChanged(flags: event.flags)
    }

    private func handleFlagsChanged(flags: CGEventFlags) {
        let isHoldingScreenshotModifiers = Self.hasScreenshotModifiers(flags)

        if isHoldingScreenshotModifiers, activeShortcut == nil, !isPreparingScreenshotShortcut {
            isPreparingScreenshotShortcut = true
            onCaptureShortcutPreparation?()
        } else if !isHoldingScreenshotModifiers, activeShortcut == nil, isPreparingScreenshotShortcut {
            isPreparingScreenshotShortcut = false
            onCaptureCancelled?()
        }
    }

    private func finishInteractiveCapture() {
        if activeShortcut == .interactiveScreenshot {
            activeShortcut = nil
            onInteractiveCaptureFinished?()
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

private extension NSEvent {
    var cgFlags: CGEventFlags {
        CGEventFlags(rawValue: UInt64(modifierFlags.rawValue))
    }
}
