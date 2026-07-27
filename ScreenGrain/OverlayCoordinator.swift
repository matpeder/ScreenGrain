import AppKit
import CoreGraphics

final class OverlayCoordinator {
    private struct TextureKey: Equatable {
        let mode: GrainMode
        let seed: UInt64
        let intensity: Double
        let character: Double
    }

    private var overlays: [CGDirectDisplayID: OverlayPanel] = [:]
    private var applicationObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var currentSettings = GrainSettings.initial
    private var textureKey: TextureKey?
    private var texture: CGImage?

    func start(settings: GrainSettings) {
        guard applicationObservers.isEmpty, workspaceObservers.isEmpty else { return }
        currentSettings = settings

        applicationObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reconcile()
            }
        )

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            workspaceObservers.append(
                workspaceCenter.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.reconcile()
                }
            )
        }

        rebuildTextureIfNeeded()
        reconcile()
    }

    func apply(settings: GrainSettings) {
        currentSettings = settings
        rebuildTextureIfNeeded()
        reconcile()
    }

    func stop() {
        overlays.values.forEach {
            $0.orderOut(nil)
            $0.close()
        }
        overlays.removeAll()
        applicationObservers.forEach(NotificationCenter.default.removeObserver)
        applicationObservers.removeAll()
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(workspaceCenter.removeObserver)
        workspaceObservers.removeAll()
    }

    private func rebuildTextureIfNeeded() {
        let key = TextureKey(
            mode: currentSettings.mode,
            seed: currentSettings.seed,
            intensity: currentSettings.intensity,
            character: currentSettings.character
        )
        guard key != textureKey || texture == nil else { return }

        let bitmap = TextureGenerator().generate(
            mode: key.mode,
            seed: key.seed,
            intensity: key.intensity,
            character: key.character
        )
        texture = bitmap.makeCGImage()
        textureKey = key
    }

    private func reconcile() {
        var screensByDisplayID: [CGDirectDisplayID: NSScreen] = [:]
        for screen in NSScreen.screens {
            guard let displayID = screen.directDisplayID else { continue }
            screensByDisplayID[displayID] = screen
        }

        for displayID in Set(overlays.keys).subtracting(screensByDisplayID.keys) {
            overlays.removeValue(forKey: displayID)?.close()
        }

        guard currentSettings.enabled, let texture else {
            overlays.values.forEach { $0.orderOut(nil) }
            return
        }

        for (displayID, screen) in screensByDisplayID {
            let overlay: OverlayPanel
            if let existing = overlays[displayID] {
                overlay = existing
            } else {
                overlay = OverlayPanel(screen: screen)
                overlays[displayID] = overlay
            }

            overlay.apply(
                texture: texture,
                frame: screen.frame,
                backingScale: screen.backingScaleFactor,
                opacity: currentSettings.opacity,
                grainSize: currentSettings.grainSize
            )
            overlay.orderFrontRegardless()
        }
    }
}

private extension NSScreen {
    var directDisplayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}

private extension TextureBitmap {
    func makeCGImage() -> CGImage? {
        let data = Data(premultipliedRGBA) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
