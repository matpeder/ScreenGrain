import AppKit

final class OverlayPanel: NSPanel {
    private let textureView = TiledTextureView()

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .screenGrainOverlay
        collectionBehavior = [
            .canJoinAllSpaces,
            .canJoinAllApplications,
            .stationary,
            .ignoresCycle,
        ]
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = false
        isMovable = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        canHide = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        contentView = textureView
    }

    func apply(
        texture: CGImage,
        frame: NSRect,
        backingScale: CGFloat,
        densityScale: CGFloat,
        opacity: Double,
        grainSize: Double
    ) {
        setFrame(frame, display: false)
        alphaValue = opacity
        textureView.update(
            texture: texture,
            backingScale: backingScale,
            densityScale: densityScale,
            grainSize: grainSize
        )
    }
}

extension NSWindow.Level {
    static let screenGrainOverlay = NSWindow.Level(rawValue: popUpMenu.rawValue + 1)
}

enum GrainTileScale {
    static func backingPixelDensity(
        pixelWidth: Int,
        pixelHeight: Int,
        physicalSize: CGSize,
        backingScale: CGFloat
    ) -> CGFloat? {
        guard physicalSize.width > 0, physicalSize.height > 0, backingScale > 0 else { return nil }

        let horizontal = CGFloat(pixelWidth) / physicalSize.width * backingScale
        let vertical = CGFloat(pixelHeight) / physicalSize.height * backingScale
        guard horizontal.isFinite, vertical.isFinite, horizontal > 0, vertical > 0 else {
            return nil
        }
        return (horizontal + vertical) / 2
    }

    static func relativeDensity(display: CGFloat?, reference: CGFloat?) -> CGFloat {
        guard let display, let reference, display > 0, reference > 0 else { return 1 }
        return min(display / reference, 1)
    }

    static func tileSide(
        textureWidth: Int,
        backingScale: CGFloat,
        densityScale: CGFloat,
        grainSize: Double
    ) -> CGFloat {
        guard backingScale > 0 else { return CGFloat(textureWidth) * CGFloat(grainSize) }
        return CGFloat(textureWidth) / backingScale * densityScale * CGFloat(grainSize)
    }
}

private final class TiledTextureView: NSView {
    private var texture: CGImage?
    private var tileSide: CGFloat = 256
    private var shouldSmoothDownsample = false

    override var isOpaque: Bool { false }

    func update(
        texture: CGImage,
        backingScale: CGFloat,
        densityScale: CGFloat,
        grainSize: Double
    ) {
        self.texture = texture
        tileSide = GrainTileScale.tileSide(
            textureWidth: texture.width,
            backingScale: backingScale,
            densityScale: densityScale,
            grainSize: grainSize
        )
        shouldSmoothDownsample = densityScale < 1
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let texture, let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        context.setShouldAntialias(false)
        context.interpolationQuality = shouldSmoothDownsample ? .medium : .none

        let startX = floor(dirtyRect.minX / tileSide) * tileSide
        let startY = floor(dirtyRect.minY / tileSide) * tileSide
        var y = startY
        while y < dirtyRect.maxY {
            var x = startX
            while x < dirtyRect.maxX {
                context.draw(texture, in: CGRect(x: x, y: y, width: tileSide, height: tileSide))
                x += tileSide
            }
            y += tileSide
        }
        context.restoreGState()
    }
}
