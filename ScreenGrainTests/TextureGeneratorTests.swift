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

        XCTAssertLessThan(abs(horizontalCorrelation(noise, lag: 1)), 0.06)
        XCTAssertGreaterThan(horizontalCorrelation(film, lag: 1), 0.65)
        XCTAssertGreaterThan(horizontalCorrelation(film, lag: 2), 0.19)
        XCTAssertLessThan(normalizedHorizontalDifferenceEnergy(film), 0.65)
    }

    func testFilmGrainIsStatisticallyContinuousAcrossTileEdges() {
        let film = TextureGenerator.scalarField(
            mode: .filmGrain,
            seed: 456,
            dimension: dimension
        )

        let horizontal = differenceEnergies(film, horizontal: true)
        let vertical = differenceEnergies(film, horizontal: false)
        XCTAssertEqual(
            horizontal.seam,
            horizontal.interior,
            accuracy: horizontal.interior * 0.35
        )
        XCTAssertEqual(
            vertical.seam,
            vertical.interior,
            accuracy: vertical.interior * 0.35
        )
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
            colorMode: .monochrome,
            dimension: dimension
        )

        XCTAssertTrue(bitmap.premultipliedRGBA.allSatisfy { $0 == 0 })
    }

    func testColorModeIsVisiblyMoreColorfulThanMonochrome() {
        let monochrome = generator.generate(
            mode: .noise,
            seed: 5,
            intensity: 0.7,
            colorMode: .monochrome,
            dimension: dimension
        )
        let colored = generator.generate(
            mode: .noise,
            seed: 5,
            intensity: 0.7,
            colorMode: .color,
            dimension: dimension
        )

        for index in stride(from: 0, to: monochrome.premultipliedRGBA.count, by: 4) {
            XCTAssertEqual(monochrome.premultipliedRGBA[index], monochrome.premultipliedRGBA[index + 1])
            XCTAssertEqual(monochrome.premultipliedRGBA[index + 1], monochrome.premultipliedRGBA[index + 2])
            XCTAssertEqual(
                monochrome.premultipliedRGBA[index + 3],
                colored.premultipliedRGBA[index + 3]
            )
        }
        var channelDifference = 0
        for index in stride(from: 0, to: colored.premultipliedRGBA.count, by: 4) {
            let red = Int(colored.premultipliedRGBA[index])
            let green = Int(colored.premultipliedRGBA[index + 1])
            let blue = Int(colored.premultipliedRGBA[index + 2])
            channelDifference += abs(red - green) + abs(green - blue) + abs(blue - red)
        }
        let displayedDifference =
            Double(channelDifference)
            / Double(dimension * dimension)
            * GrainSettings.initial.opacity
        XCTAssertGreaterThan(displayedDifference, 5)
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
            colorMode: .color,
            dimension: dimension
        )
    }

    private func horizontalCorrelation(_ values: [Int32], lag: Int) -> Double {
        let doubles = values.map(Double.init)
        let mean = doubles.reduce(0, +) / Double(doubles.count)
        var numerator = 0.0
        var denominator = 0.0

        for y in 0..<dimension {
            for x in 0..<dimension {
                let current = doubles[y * dimension + x] - mean
                let next = doubles[y * dimension + (x + lag) % dimension] - mean
                numerator += current * next
                denominator += current * current
            }
        }
        return numerator / denominator
    }

    private func normalizedHorizontalDifferenceEnergy(_ values: [Int32]) -> Double {
        let doubles = values.map(Double.init)
        let mean = doubles.reduce(0, +) / Double(doubles.count)
        var differenceEnergy = 0.0
        var signalEnergy = 0.0

        for y in 0..<dimension {
            for x in 0..<dimension {
                let current = doubles[y * dimension + x] - mean
                let next = doubles[y * dimension + (x + 1) % dimension] - mean
                differenceEnergy += (next - current) * (next - current)
                signalEnergy += current * current
            }
        }
        return differenceEnergy / signalEnergy
    }

    private func differenceEnergies(
        _ values: [Int32],
        horizontal: Bool
    ) -> (seam: Double, interior: Double) {
        var seamEnergy = 0.0
        var interiorEnergy = 0.0

        for outer in 0..<dimension {
            let seamStart = horizontal
                ? outer * dimension + dimension - 1
                : (dimension - 1) * dimension + outer
            let seamEnd = horizontal ? outer * dimension : outer
            seamEnergy += squaredDifference(values[seamStart], values[seamEnd])

            for inner in 0..<(dimension - 1) {
                let start = horizontal
                    ? outer * dimension + inner
                    : inner * dimension + outer
                let end = horizontal ? start + 1 : start + dimension
                interiorEnergy += squaredDifference(values[start], values[end])
            }
        }

        return (
            seam: seamEnergy / Double(dimension),
            interior: interiorEnergy / Double(dimension * (dimension - 1))
        )
    }

    private func squaredDifference(_ first: Int32, _ second: Int32) -> Double {
        let difference = Double(second) - Double(first)
        return difference * difference
    }
}
