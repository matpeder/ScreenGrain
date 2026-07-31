import AppKit
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
        expected.colorMode = .color
        expected.seed = 42
        expected.hidesInCaptures = true
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
        XCTAssertFalse(GrainSettings.initial.hidesInCaptures)
        XCTAssertFalse(GrainSettings.initial.launchAtLogin)
        XCTAssertEqual(GrainSettings.initial.colorMode, .monochrome)
        XCTAssertEqual(GrainSettings.opacityRange, 0...1)
        XCTAssertEqual(GrainSettings.intensityRange, 0...1)
    }

    func testLegacyCharacterMigratesAtPreviousVisualBoundary() throws {
        for value in [0.0, 0.04] {
            let settings = try decodeLegacySettings(character: value)
            XCTAssertEqual(settings.colorMode, .monochrome)
            XCTAssertFalse(settings.hidesInCaptures)
        }
        for value in [0.05, 0.1, 0.18, 0.8] {
            XCTAssertEqual(try decodeLegacySettings(character: value).colorMode, .color)
        }
    }

    func testSavedColorModeTakesPrecedenceOverLegacyCharacter() throws {
        let settings = try decodeLegacySettings(
            character: 0.8,
            colorModeRawValue: GrainColorMode.monochrome.rawValue
        )

        XCTAssertEqual(settings.colorMode, .monochrome)
    }

    func testUnknownSavedColorModeFallsBackToLegacyCharacter() throws {
        let settings = try decodeLegacySettings(
            character: 0.1,
            colorModeRawValue: "sepia"
        )

        XCTAssertEqual(settings.colorMode, .color)
    }

    func testPreviousCapturePreferenceDoesNotEnableInputMonitoring() throws {
        let settings = try decodeLegacySettings(character: 0, screenshotUIVisibility: true)

        XCTAssertFalse(settings.hidesInCaptures)
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
            colorMode: model.settings.colorMode,
            dimension: 48
        )

        model.reroll()

        XCTAssertNotEqual(model.settings.seed, originalSeed)
        XCTAssertEqual(SettingsPersistence(defaults: defaults).load().seed, model.settings.seed)
        let rerolledTexture = TextureGenerator().generate(
            mode: model.settings.mode,
            seed: model.settings.seed,
            intensity: model.settings.intensity,
            colorMode: model.settings.colorMode,
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
        persistence.save(malformed)

        let restored = persistence.load()

        XCTAssertEqual(restored.opacity, 0)
        XCTAssertEqual(restored.grainSize, 0.65)
        XCTAssertEqual(restored.intensity, 1)
    }

    func testSettingsPanelIsCompactAndUsesExplicitSwitches() {
        let suite = "ScreenGrainTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = SettingsViewController(model: AppModel(defaults: defaults))

        _ = controller.view

        XCTAssertEqual(controller.preferredContentSize.width, 320)
        XCTAssertLessThan(controller.preferredContentSize.height, 400)
        let views = descendants(of: controller.view)
        XCTAssertEqual(views.compactMap { $0 as? NSSwitch }.count, 3)
        XCTAssertFalse(views.contains { $0 is NSPopUpButton })
        let labels = views.compactMap { ($0 as? NSTextField)?.stringValue }
        XCTAssertFalse(labels.contains("Static texture on every display"))
        XCTAssertFalse(labels.contains("Preset"))
        XCTAssertFalse(labels.contains("Character"))
        XCTAssertTrue(labels.contains("Hide in Captures"))
    }

    private func decodeLegacySettings(
        character: Double,
        colorModeRawValue: String? = nil,
        screenshotUIVisibility: Bool? = nil
    ) throws -> GrainSettings {
        var payload: [String: Any] = [
            "enabled": true,
            "mode": "filmGrain",
            "opacity": 0.2,
            "grainSize": 1.2,
            "intensity": 0.6,
            "character": character,
            "seed": 42,
            "launchAtLogin": false,
        ]
        payload["colorMode"] = colorModeRawValue
        payload["showsInScreenshotUI"] = screenshotUIVisibility
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(GrainSettings.self, from: data)
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants)
    }
}
