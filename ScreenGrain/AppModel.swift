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
    private var started = false

    init(defaults: UserDefaults = .standard) {
        persistence = SettingsPersistence(defaults: defaults)
        settings = persistence.load()
        captureShortcutMonitor.onCaptureShortcut = { [weak self] shortcut in
            self?.handleCaptureShortcut(shortcut)
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
        if settings.hidesInCaptures, !startCaptureShortcutMonitor(requestingPermission: false) {
            var updated = settings
            updated.hidesInCaptures = false
            commit(updated)
            captureMessage = "Input Monitoring is no longer allowed, so Hide in Captures was turned off."
            onChange?()
        }
    }

    func stop() {
        stopCaptureShortcutMonitor()
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
            captureMessage = nil
            onChange?()
            return
        }

        guard startCaptureShortcutMonitor(requestingPermission: true) else {
            var updated = settings
            updated.hidesInCaptures = false
            commit(updated)
            captureMessage = "Allow Input Monitoring in System Settings, then turn this on again."
            onChange?()
            return
        }

        captureMessage = nil
        set(\.hidesInCaptures, to: true)
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

    private func startCaptureShortcutMonitor(requestingPermission: Bool) -> Bool {
        switch captureShortcutMonitor.start(requestingPermission: requestingPermission) {
        case .started:
            return true
        case .permissionRequired:
            return false
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

        captureRestoreWork?.cancel()
        captureRestoreWork = nil
        overlayCoordinator.setHiddenForCapture(true)

        if shortcut == .immediateScreenshot {
            scheduleCaptureRestore(after: 1)
        }
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
