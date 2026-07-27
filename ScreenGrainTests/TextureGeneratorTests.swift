import XCTest
@testable import ScreenGrain

final class TextureGeneratorTests: XCTestCase {
    private let generator = TextureGenerator()
    private let dimension = 96

    func testIdenticalInputsProduceIdenticalBytes() {
        let first = makeBitmap(mode: .noise, seed: 123)
        let second = makeBitmap(mode: .noise, seed: 123)

        XCTAssertEqual(first, second)
    }

    func testDifferentSeedChangesOutput() {
        let first = makeBitmap(mode: .noise, seed: 123)
        let second = makeBitmap(mode: .noise, seed: 124)

        XCTAssertNotEqual(first.premultipliedRGBA, second.premultipliedRGBA)
    }

    func testModesHaveMeasurablyDifferentSpatialStructure() {
        let noise = TextureGenerator.scalarField(
            mode: .noise,
            seed: 123,
            dimension: dimension
        )
        let film = TextureGenerator.scalarField(
            mode: .filmGrain,
            seed: 123,
            dimension: dimension
        )

        XCTAssertLessThan(abs(horizontalLagOneCorrelation(noise)), 0.06)
        XCTAssertGreaterThan(horizontalLagOneCorrelation(film), 0.4)
    }

    func testGeneratedValuesAreValidPremultipliedRGBA() {
        for mode in GrainMode.allCases {
            let bitmap = makeBitmap(mode: mode, seed: 987)
            XCTAssertEqual(bitmap.premultipliedRGBA.count, dimension * dimension * 4)
            for index in stride(from: 0, to: bitmap.premultipliedRGBA.count, by: 4) {
                let alpha = bitmap.premultipliedRGBA[index + 3]
                XCTAssertLessThanOrEqual(bitmap.premultipliedRGBA[index], alpha)
                XCTAssertLessThanOrEqual(bitmap.premultipliedRGBA[index + 1], alpha)
                XCTAssertLessThanOrEqual(bitmap.premultipliedRGBA[index + 2], alpha)
            }
        }
    }

    func testIntensityZeroIsTransparent() {
        let bitmap = generator.generate(
            mode: .noise,
            seed: 5,
            intensity: 0,
            character: 0,
            dimension: dimension
        )

        XCTAssertTrue(bitmap.premultipliedRGBA.allSatisfy { $0 == 0 })
    }

    func testMonochromeHasEqualChannelsAndCharacterAddsSubtleColor() {
        let monochrome = generator.generate(
            mode: .noise,
            seed: 5,
            intensity: 0.7,
            character: 0,
            dimension: dimension
        )
        let colored = generator.generate(
            mode: .noise,
            seed: 5,
            intensity: 0.7,
            character: 1,
            dimension: dimension
        )

        for index in stride(from: 0, to: monochrome.premultipliedRGBA.count, by: 4) {
            XCTAssertEqual(monochrome.premultipliedRGBA[index], monochrome.premultipliedRGBA[index + 1])
            XCTAssertEqual(monochrome.premultipliedRGBA[index + 1], monochrome.premultipliedRGBA[index + 2])
        }
        var containsColor = false
        for index in stride(from: 0, to: colored.premultipliedRGBA.count, by: 4) {
            let red = colored.premultipliedRGBA[index]
            let green = colored.premultipliedRGBA[index + 1]
            let blue = colored.premultipliedRGBA[index + 2]
            if red != green || green != blue {
                containsColor = true
                break
            }
        }
        XCTAssertTrue(containsColor)
    }

    func testTextureIsApproximatelyNeutralOverMidGray() {
        for mode in GrainMode.allCases {
            let bitmap = makeBitmap(mode: mode, seed: 789)
            var totals = [Double](repeating: 0, count: 3)
            let pixelCount = bitmap.width * bitmap.height

            for index in stride(from: 0, to: bitmap.premultipliedRGBA.count, by: 4) {
                let alpha = Double(bitmap.premultipliedRGBA[index + 3])
                for channel in 0..<3 {
                    totals[channel] += Double(bitmap.premultipliedRGBA[index + channel])
                        + 128 * (255 - alpha) / 255
                }
            }

            for total in totals {
                XCTAssertEqual(total / Double(pixelCount), 128, accuracy: 2.0)
            }
        }
    }

    private func makeBitmap(mode: GrainMode, seed: UInt64) -> TextureBitmap {
        generator.generate(
            mode: mode,
            seed: seed,
            intensity: 0.7,
            character: 0.12,
            dimension: dimension
        )
    }

    private func horizontalLagOneCorrelation(_ values: [Int32]) -> Double {
        let doubles = values.map(Double.init)
        let mean = doubles.reduce(0, +) / Double(doubles.count)
        var numerator = 0.0
        var denominator = 0.0

        for y in 0..<dimension {
            for x in 0..<dimension {
                let current = doubles[y * dimension + x] - mean
                let next = doubles[y * dimension + (x + 1) % dimension] - mean
                numerator += current * next
                denominator += current * current
            }
        }
        return numerator / denominator
    }
}
