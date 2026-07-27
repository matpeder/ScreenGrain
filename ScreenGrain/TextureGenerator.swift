import Foundation

struct TextureBitmap: Equatable {
    let width: Int
    let height: Int
    let premultipliedRGBA: [UInt8]
}

struct TextureGenerator {
    static let defaultDimension = 512

    func generate(
        mode: GrainMode,
        seed: UInt64,
        intensity: Double,
        character: Double,
        dimension: Int = Self.defaultDimension
    ) -> TextureBitmap {
        precondition(dimension > 1)

        let luminance = Self.scalarField(
            mode: mode,
            seed: seed ^ 0xA076_1D64_78BD_642F,
            dimension: dimension
        )
        let red = Self.scalarField(
            mode: mode,
            seed: seed ^ 0xE703_7ED1_A0B4_28DB,
            dimension: dimension
        )
        let green = Self.scalarField(
            mode: mode,
            seed: seed ^ 0x8EBC_6AF0_9C88_C6E3,
            dimension: dimension
        )
        let blue = Self.scalarField(
            mode: mode,
            seed: seed ^ 0x5899_65CC_7537_4CC3,
            dimension: dimension
        )

        let intensityQ = Int64((intensity.clamped(to: 0...1) * 1024).rounded())
        let chromaQ = Int64((character.clamped(to: 0...1) * 205).rounded())
        var bytes = [UInt8]()
        bytes.reserveCapacity(dimension * dimension * 4)

        for index in luminance.indices {
            let luma = Int64(luminance[index])
            let dR = ((1024 - chromaQ) * luma + chromaQ * Int64(red[index])) / 1024
            let dG = ((1024 - chromaQ) * luma + chromaQ * Int64(green[index])) / 1024
            let dB = ((1024 - chromaQ) * luma + chromaQ * Int64(blue[index])) / 1024
            let amplitude = max(abs(dR), abs(dG), abs(dB))

            guard amplitude > 0, intensityQ > 0 else {
                bytes.append(contentsOf: [0, 0, 0, 0])
                continue
            }

            let alpha = min(255, amplitude * intensityQ * 255 / (32768 * 1024))
            let divisor = 2 * amplitude
            bytes.append(UInt8(clamping: alpha * (amplitude + dR) / divisor))
            bytes.append(UInt8(clamping: alpha * (amplitude + dG) / divisor))
            bytes.append(UInt8(clamping: alpha * (amplitude + dB) / divisor))
            bytes.append(UInt8(clamping: alpha))
        }

        return TextureBitmap(
            width: dimension,
            height: dimension,
            premultipliedRGBA: bytes
        )
    }

    static func scalarField(
        mode: GrainMode,
        seed: UInt64,
        dimension: Int
    ) -> [Int32] {
        var generator = SplitMix64(seed: seed)
        var samples = (0..<(dimension * dimension)).map { _ in
            Int32(generator.nextHighWord()) - 32768
        }

        if mode == .filmGrain {
            samples = correlate(samples, dimension: dimension)
        }
        return samples
    }

    private static func correlate(_ samples: [Int32], dimension: Int) -> [Int32] {
        var horizontal = [Int64](repeating: 0, count: samples.count)
        var correlated = [Int32](repeating: 0, count: samples.count)

        for y in 0..<dimension {
            for x in 0..<dimension {
                let left = y * dimension + (x - 1 + dimension) % dimension
                let center = y * dimension + x
                let right = y * dimension + (x + 1) % dimension
                horizontal[center] =
                    Int64(samples[left]) + 2 * Int64(samples[center]) + Int64(samples[right])
            }
        }

        for y in 0..<dimension {
            for x in 0..<dimension {
                let above = ((y - 1 + dimension) % dimension) * dimension + x
                let center = y * dimension + x
                let below = ((y + 1) % dimension) * dimension + x
                let value = (horizontal[above] + 2 * horizontal[center] + horizontal[below]) / 6
                correlated[center] = Int32(clamping: value)
            }
        }

        return correlated
    }
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextHighWord() -> UInt16 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return UInt16(truncatingIfNeeded: value >> 48)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

