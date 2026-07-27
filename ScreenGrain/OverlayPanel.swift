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
        opacity: Double,
        grainSize: Double
    ) {
        setFrame(frame, display: false)
        alphaValue = opacity
        textureView.update(
            texture: texture,
            backingScale: backingScale,
            grainSize: grainSize
        )
    }
}

extension NSWindow.Level {
    static let screenGrainOverlay = NSWindow.Level(rawValue: popUpMenu.rawValue + 1)
}

private final class TiledTextureView: NSView {
    private var texture: CGImage?
    private var tileSide: CGFloat = 256

    override var isOpaque: Bool { false }

    func update(texture: CGImage, backingScale: CGFloat, grainSize: Double) {
        self.texture = texture
        tileSide = CGFloat(texture.width) / backingScale * CGFloat(grainSize)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let texture, let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        context.setShouldAntialias(false)
        context.interpolationQuality = .none

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
