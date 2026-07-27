import AppKit

final class AppModel {
    private(set) var settings: GrainSettings
    private(set) var loginItemMessage: String?
    var onChange: (() -> Void)?

    private let persistence: SettingsPersistence
    private let overlayCoordinator = OverlayCoordinator()
    private let loginItemService = LoginItemService()
    private var started = false

    init(defaults: UserDefaults = .standard) {
        persistence = SettingsPersistence(defaults: defaults)
        settings = persistence.load()
    }

    func start() {
        guard !started else { return }
        started = true
        refreshLoginItemStatus()
        overlayCoordinator.start(settings: settings)
    }

    func stop() {
        overlayCoordinator.stop()
    }

    func set<Value>(
        _ keyPath: WritableKeyPath<GrainSettings, Value>,
        to value: Value,
        clearsPreset: Bool = true
    ) {
        var updated = settings
        updated[keyPath: keyPath] = value
        if clearsPreset {
            updated.presetID = nil
        }
        commit(updated)
    }

    func apply(_ preset: GrainPreset) {
        var updated = settings
        updated.apply(preset)
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

    private func refreshLoginItemStatus() {
        let status = loginItemService.status
        var updated = settings

        switch status {
        case .enabled:
            updated.launchAtLogin = true
            loginItemMessage = nil
        case .requiresApproval:
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
