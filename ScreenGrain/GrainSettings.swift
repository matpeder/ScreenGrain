import Foundation

enum GrainMode: String, Codable, CaseIterable, Identifiable {
    case noise
    case filmGrain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noise: "Noise"
        case .filmGrain: "Film Grain"
        }
    }
}

enum GrainColorMode: String, Codable, CaseIterable {
    case monochrome
    case color

    var title: String {
        switch self {
        case .monochrome: "Monochrome"
        case .color: "Color"
        }
    }
}

struct GrainSettings: Equatable {
    static let opacityRange = 0.0...1.0
    static let grainSizeRange = 0.65...2.5
    static let intensityRange = 0.0...1.0

    var enabled: Bool
    var mode: GrainMode
    var opacity: Double
    var grainSize: Double
    var intensity: Double
    var colorMode: GrainColorMode
    var seed: UInt64
    var showsInCaptures: Bool
    var launchAtLogin: Bool

    static let initial = GrainSettings(
        enabled: true,
        mode: .noise,
        opacity: 0.075,
        grainSize: 1.0,
        intensity: 0.58,
        colorMode: .monochrome,
        seed: 0x5343_5245_454E_4752,
        showsInCaptures: false,
        launchAtLogin: false
    )

    func sanitized() -> GrainSettings {
        var result = self
        result.opacity = Self.sanitize(
            opacity,
            range: Self.opacityRange,
            fallback: Self.initial.opacity
        )
        result.grainSize = Self.sanitize(
            grainSize,
            range: Self.grainSizeRange,
            fallback: Self.initial.grainSize
        )
        result.intensity = Self.sanitize(
            intensity,
            range: Self.intensityRange,
            fallback: Self.initial.intensity
        )
        return result
    }

    private static func sanitize(
        _ value: Double,
        range: ClosedRange<Double>,
        fallback: Double
    ) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

extension GrainSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case enabled
        case mode
        case opacity
        case grainSize
        case intensity
        case colorMode
        case character
        case seed
        case showsInCaptures
        case showsInScreenshotUI
        case launchAtLogin
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decode(Bool.self, forKey: .enabled)
        mode = try values.decode(GrainMode.self, forKey: .mode)
        opacity = try values.decode(Double.self, forKey: .opacity)
        grainSize = try values.decode(Double.self, forKey: .grainSize)
        intensity = try values.decode(Double.self, forKey: .intensity)
        seed = try values.decode(UInt64.self, forKey: .seed)
        if let savedValue = try values.decodeIfPresent(Bool.self, forKey: .showsInCaptures) {
            showsInCaptures = savedValue
        } else {
            showsInCaptures = try values.decodeIfPresent(Bool.self, forKey: .showsInScreenshotUI) ?? false
        }
        launchAtLogin = try values.decode(Bool.self, forKey: .launchAtLogin)

        if let savedMode = try? values.decode(GrainColorMode.self, forKey: .colorMode) {
            colorMode = savedMode
        } else {
            let legacyCharacter = try values.decodeIfPresent(Double.self, forKey: .character) ?? 0
            colorMode = legacyCharacter < 0.05 ? .monochrome : .color
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(enabled, forKey: .enabled)
        try values.encode(mode, forKey: .mode)
        try values.encode(opacity, forKey: .opacity)
        try values.encode(grainSize, forKey: .grainSize)
        try values.encode(intensity, forKey: .intensity)
        try values.encode(colorMode, forKey: .colorMode)
        try values.encode(seed, forKey: .seed)
        try values.encode(showsInCaptures, forKey: .showsInCaptures)
        try values.encode(launchAtLogin, forKey: .launchAtLogin)
    }
}
