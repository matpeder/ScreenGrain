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

struct GrainSettings: Codable, Equatable {
    var enabled: Bool
    var mode: GrainMode
    var opacity: Double
    var grainSize: Double
    var intensity: Double
    var character: Double
    var seed: UInt64
    var presetID: String?
    var launchAtLogin: Bool

    static let initial = GrainSettings(
        enabled: true,
        mode: .noise,
        opacity: 0.075,
        grainSize: 1.0,
        intensity: 0.58,
        character: 0.04,
        seed: 0x5343_5245_454E_4752,
        presetID: GrainPreset.whisper.id,
        launchAtLogin: false
    )

    mutating func apply(_ preset: GrainPreset) {
        mode = preset.mode
        opacity = preset.opacity
        grainSize = preset.grainSize
        intensity = preset.intensity
        character = preset.character
        presetID = preset.id
    }
}

struct GrainPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let mode: GrainMode
    let opacity: Double
    let grainSize: Double
    let intensity: Double
    let character: Double

    static let whisper = GrainPreset(
        id: "whisper",
        name: "Whisper",
        mode: .noise,
        opacity: 0.075,
        grainSize: 1.0,
        intensity: 0.58,
        character: 0.04
    )

    static let fine = GrainPreset(
        id: "fine",
        name: "Fine",
        mode: .noise,
        opacity: 0.11,
        grainSize: 0.78,
        intensity: 0.76,
        character: 0.0
    )

    static let softFilm = GrainPreset(
        id: "soft-film",
        name: "Soft Film",
        mode: .filmGrain,
        opacity: 0.1,
        grainSize: 1.35,
        intensity: 0.62,
        character: 0.1
    )

    static let pronounced = GrainPreset(
        id: "pronounced",
        name: "Pronounced",
        mode: .filmGrain,
        opacity: 0.17,
        grainSize: 1.8,
        intensity: 0.82,
        character: 0.18
    )

    static let all: [GrainPreset] = [
        .whisper,
        .fine,
        .softFilm,
        .pronounced,
    ]
}

