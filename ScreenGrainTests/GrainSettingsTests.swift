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

    func testRerollChangesPersistedSeedAndTexture() {
        let suite = "ScreenGrainTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        let originalSeed = model.settings.seed
        let originalTexture = TextureGenerator().generate(
            mode: model.settings.mode,
            seed: originalSeed,
            intensity: model.settings.intensity,
            character: model.settings.character,
            dimension: 48
        )

        model.reroll()

        XCTAssertNotEqual(model.settings.seed, originalSeed)
        XCTAssertEqual(SettingsPersistence(defaults: defaults).load().seed, model.settings.seed)
        let rerolledTexture = TextureGenerator().generate(
            mode: model.settings.mode,
            seed: model.settings.seed,
            intensity: model.settings.intensity,
            character: model.settings.character,
            dimension: 48
        )
        XCTAssertNotEqual(rerolledTexture, originalTexture)
    }

    func testPersistedVisualValuesAreClampedToUIRanges() {
        let suite = "ScreenGrainTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = SettingsPersistence(defaults: defaults)
        var malformed = GrainSettings.initial
        malformed.opacity = -10
        malformed.grainSize = 0
        malformed.intensity = 20
        malformed.character = -1
        malformed.presetID = "removed-preset"
        persistence.save(malformed)

        let restored = persistence.load()

        XCTAssertEqual(restored.opacity, 0.02)
        XCTAssertEqual(restored.grainSize, 0.65)
        XCTAssertEqual(restored.intensity, 1)
        XCTAssertEqual(restored.character, 0)
        XCTAssertNil(restored.presetID)
    }
}
