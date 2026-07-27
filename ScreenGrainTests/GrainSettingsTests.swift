import XCTest
@testable import ScreenGrain

final class GrainSettingsTests: XCTestCase {
    func testSettingsPersistAndRestore() {
        let suite = "ScreenGrainTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = SettingsPersistence(defaults: defaults)
        var expected = GrainSettings.initial
        expected.enabled = false
        expected.mode = .filmGrain
        expected.opacity = 0.19
        expected.seed = 42
        expected.launchAtLogin = true

        persistence.save(expected)

        XCTAssertEqual(persistence.load(), expected)
    }

    func testMissingSettingsUseRestrainedEnabledDefault() {
        let suite = "ScreenGrainTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(SettingsPersistence(defaults: defaults).load(), .initial)
        XCTAssertTrue(GrainSettings.initial.enabled)
        XCTAssertFalse(GrainSettings.initial.launchAtLogin)
        XCTAssertEqual(GrainSettings.initial.presetID, GrainPreset.whisper.id)
    }

    func testEveryPresetMapsToUnderlyingSettings() {
        for preset in GrainPreset.all {
            var settings = GrainSettings.initial
            let originalSeed = settings.seed
            let originalEnabled = settings.enabled
            settings.apply(preset)

            XCTAssertEqual(settings.mode, preset.mode)
            XCTAssertEqual(settings.opacity, preset.opacity)
            XCTAssertEqual(settings.grainSize, preset.grainSize)
            XCTAssertEqual(settings.intensity, preset.intensity)
            XCTAssertEqual(settings.character, preset.character)
            XCTAssertEqual(settings.presetID, preset.id)
            XCTAssertEqual(settings.seed, originalSeed)
            XCTAssertEqual(settings.enabled, originalEnabled)
        }
    }
}

