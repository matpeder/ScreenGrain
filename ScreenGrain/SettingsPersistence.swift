import Foundation

struct SettingsPersistence {
    static let storageKey = "ScreenGrain.settings.v1"

    let defaults: UserDefaults

    func load() -> GrainSettings {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let settings = try? JSONDecoder().decode(GrainSettings.self, from: data)
        else {
            return .initial
        }
        return settings.sanitized()
    }

    func save(_ settings: GrainSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
