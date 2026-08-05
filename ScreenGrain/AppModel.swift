import AppKit

final class AppModel {
    private(set) var settings: GrainSettings
    private(set) var loginItemMessage: String?
    private(set) var captureMessage: String?
    var onChange: (() -> Void)?

    private let persistence: SettingsPersistence
    private let overlayCoordinator = OverlayCoordinator()
    private let loginItemService = LoginItemService()
    private let captureShortcutMonitor = CaptureShortcutMonitor()
    private var captureRestoreWork: DispatchWorkItem?
    private var lastDetectedCaptureShortcut: CaptureShortcutKind?
    private var applicationActivationObserver: NSObjectProtocol?
    private var started = false

    init(defaults: UserDefaults = .standard) {
        persistence = SettingsPersistence(defaults: defaults)
        settings = persistence.load()
        captureShortcutMonitor.onCaptureShortcut = { [weak self] shortcut in
            self?.handleCaptureShortcut(shortcut)
        }
        captureShortcutMonitor.onCaptureShortcutPreparation = { [weak self] in
            self?.hideForCapture()
        }
        captureShortcutMonitor.onInteractiveCaptureFinished = { [weak self] in
            self?.restoreAfterInteractiveCapture()
        }
        captureShortcutMonitor.onCaptureCancelled = { [weak self] in
            self?.restoreAfterCapture()
        }
    }

    func start() {
        guard !started else { return }
        started = true
        refreshLoginItemStatus()
        overlayCoordinator.start(settings: settings)
        applicationActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshCaptureShortcutMonitor(requestingPermission: false)
        }
        refreshCaptureShortcutMonitor(requestingPermission: true)
    }

    func stop() {
        stopCaptureShortcutMonitor()
        if let applicationActivationObserver {
            NotificationCenter.default.removeObserver(applicationActivationObserver)
        }
        applicationActivationObserver = nil
        overlayCoordinator.stop()
    }

    func set<Value>(
        _ keyPath: WritableKeyPath<GrainSettings, Value>,
        to value: Value
    ) {
        var updated = settings
        updated[keyPath: keyPath] = value
        commit(updated)
    }

    func reroll() {
        var generator = SystemRandomNumberGenerator()
        var updated = settings
        repeat {
            updated.seed = UInt64.random(in: .min ... .max, using: &generator)
        } while updated.seed == settings.seed
        commit(updated)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            var updated = settings
            updated.launchAtLogin = enabled
            commit(updated)
            loginItemMessage = loginItemService.message
            onChange?()
        } catch {
            loginItemMessage = "Couldn’t update Login Items: \(error.localizedDescription)"
            onChange?()
        }
    }

    func setHideInCaptures(_ enabled: Bool) {
        guard enabled else {
            stopCaptureShortcutMonitor()
            set(\.hidesInCaptures, to: false)
            lastDetectedCaptureShortcut = nil
            captureMessage = nil
            onChange?()
            return
        }

        set(\.hidesInCaptures, to: true)
        refreshCaptureShortcutMonitor(requestingPermission: true)
    }

    func refreshCaptureShortcutStatus() {
        // Replacing a locally ad-hoc-signed build can invalidate an existing
        // TCC grant. Re-request only while this opt-in feature is enabled.
        refreshCaptureShortcutMonitor(requestingPermission: true)
    }

    private func refreshLoginItemStatus() {
        let status = loginItemService.status
        var updated = settings

        switch status {
        case .enabled:
            updated.launchAtLogin = true
            loginItemMessage = nil
        case .requiresApproval:
            updated.launchAtLogin = true
            loginItemMessage = loginItemService.message
        case .notFound:
            updated.launchAtLogin = false
            loginItemMessage = loginItemService.message
        case .notRegistered:
            updated.launchAtLogin = false
            loginItemMessage = nil
        @unknown default:
            loginItemMessage = "Login-item status is unavailable."
        }

        if updated != settings {
            settings = updated
            persistence.save(updated)
        }
        onChange?()
    }

    private func refreshCaptureShortcutMonitor(requestingPermission: Bool) {
        guard settings.hidesInCaptures else { return }

        switch captureShortcutMonitor.start(requestingPermission: requestingPermission) {
        case .started(let strategy):
            let listenerDescription: String
            switch strategy {
            case .eventTapAndGlobalMonitor:
                listenerDescription = "Ready — waiting for a macOS screenshot shortcut."
            case .globalMonitor:
                listenerDescription = "Ready through Accessibility monitoring."
            }

            if let lastDetectedCaptureShortcut {
                setCaptureMessage("Last detected \(lastDetectedCaptureShortcut.title). \(listenerDescription)")
            } else {
                setCaptureMessage(listenerDescription)
            }
        case .accessibilityRequired:
            setCaptureMessage("Allow Accessibility, then return to ScreenGrain.")
        case .unavailable:
            setCaptureMessage("ScreenGrain could not start its screenshot listener.")
        }
    }

    private func stopCaptureShortcutMonitor() {
        captureRestoreWork?.cancel()
        captureRestoreWork = nil
        captureShortcutMonitor.stop()
        overlayCoordinator.setHiddenForCapture(false)
    }

    private func handleCaptureShortcut(_ shortcut: CaptureShortcutKind) {
        guard settings.hidesInCaptures else { return }

        hideForCapture()
        lastDetectedCaptureShortcut = shortcut

        if shortcut == .immediateScreenshot {
            scheduleCaptureRestore(after: 1)
        }
    }

    private func hideForCapture() {
        guard settings.hidesInCaptures else { return }
        captureRestoreWork?.cancel()
        captureRestoreWork = nil
        overlayCoordinator.setHiddenForCapture(true)
    }

    private func restoreAfterInteractiveCapture() {
        guard settings.hidesInCaptures else { return }
        scheduleCaptureRestore(after: 0.6)
    }

    private func scheduleCaptureRestore(after delay: TimeInterval) {
        captureRestoreWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.restoreAfterCapture()
        }
        captureRestoreWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func restoreAfterCapture() {
        captureRestoreWork?.cancel()
        captureRestoreWork = nil
        overlayCoordinator.setHiddenForCapture(false)
    }

    private func setCaptureMessage(_ message: String?) {
        guard captureMessage != message else { return }
        captureMessage = message
        onChange?()
    }

    private func commit(_ updated: GrainSettings) {
        guard updated != settings else { return }
        settings = updated
        persistence.save(updated)
        if started {
            overlayCoordinator.apply(settings: updated)
        }
        onChange?()
    }
}

private extension CaptureShortcutKind {
    var title: String {
        switch self {
        case .immediateScreenshot: "⌘⇧3"
        case .interactiveScreenshot: "⌘⇧4"
        case .captureToolbar: "⌘⇧5"
        }
    }
}
