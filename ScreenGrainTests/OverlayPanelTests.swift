import AppKit
import XCTest
@testable import ScreenGrain

final class OverlayPanelTests: XCTestCase {
    func testScreenshotShortcutRecognitionRequiresCommandAndShift() {
        let screenshotFlags: CGEventFlags = [.maskCommand, .maskShift]

        XCTAssertEqual(
            CaptureShortcutMonitor.screenshotShortcut(keyCode: 20, flags: screenshotFlags),
            .immediateScreenshot
        )
        XCTAssertEqual(
            CaptureShortcutMonitor.screenshotShortcut(keyCode: 21, flags: screenshotFlags),
            .interactiveScreenshot
        )
        XCTAssertEqual(
            CaptureShortcutMonitor.screenshotShortcut(keyCode: 23, flags: screenshotFlags),
            .captureToolbar
        )
        XCTAssertNil(CaptureShortcutMonitor.screenshotShortcut(keyCode: 21, flags: .maskCommand))
        XCTAssertNil(CaptureShortcutMonitor.screenshotShortcut(keyCode: 0, flags: screenshotFlags))
    }

    func testGrainTileScaleMatchesPhysicalDisplayDensity() throws {
        let retinaDensity = GrainTileScale.backingPixelDensity(
            pixelWidth: 1512,
            pixelHeight: 982,
            physicalSize: CGSize(width: 301.214113, height: 195.629801),
            backingScale: 2
        )
        let lowDensity = GrainTileScale.backingPixelDensity(
            pixelWidth: 2560,
            pixelHeight: 1440,
            physicalSize: CGSize(width: 602.074065, height: 338.666662),
            backingScale: 1
        )
        let referenceDensity = try XCTUnwrap(retinaDensity)
        let externalDensity = try XCTUnwrap(lowDensity)

        let retinaTile = GrainTileScale.tileSide(
            textureWidth: 512,
            backingScale: 2,
            densityScale: GrainTileScale.relativeDensity(
                display: referenceDensity,
                reference: referenceDensity
            ),
            grainSize: 1
        )
        let lowDensityTile = GrainTileScale.tileSide(
            textureWidth: 512,
            backingScale: 1,
            densityScale: GrainTileScale.relativeDensity(
                display: externalDensity,
                reference: referenceDensity
            ),
            grainSize: 1
        )

        XCTAssertEqual(
            retinaTile * 2 / referenceDensity,
            lowDensityTile / externalDensity,
            accuracy: 0.001
        )
        XCTAssertLessThan(lowDensityTile, retinaTile)
    }

    func testGrainTileScaleFallsBackWithoutDisplayMetadata() {
        XCTAssertNil(
            GrainTileScale.backingPixelDensity(
                pixelWidth: 512,
                pixelHeight: 512,
                physicalSize: .zero,
                backingScale: 2
            )
        )
        XCTAssertEqual(GrainTileScale.relativeDensity(display: nil, reference: 5), 1)
        XCTAssertEqual(
            GrainTileScale.tileSide(
                textureWidth: 512,
                backingScale: 2,
                densityScale: 1,
                grainSize: 1.5
            ),
            384
        )
    }

    func testOverlayIsPassiveAndUsesPublicSpaceBehaviors() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let panel = OverlayPanel(screen: screen)
        defer { panel.close() }

        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertFalse(panel.canHide)
        XCTAssertTrue(panel.isExcludedFromWindowsMenu)
        XCTAssertEqual(panel.level, .screenGrainOverlay)
        XCTAssertGreaterThan(panel.level.rawValue, NSWindow.Level.popUpMenu.rawValue)
        XCTAssertLessThan(panel.level.rawValue, NSWindow.Level.screenSaver.rawValue)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllApplications))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
    }
}
