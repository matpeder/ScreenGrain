import AppKit

final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let settingsViewController: SettingsViewController

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        settingsViewController = SettingsViewController(model: model)
        super.init()

        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = settingsViewController

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }
    }

    func refresh() {
        settingsViewController.refresh()
        guard let button = statusItem.button else { return }
        let enabled = model.settings.enabled
        button.image = NSImage(
            systemSymbolName: enabled ? "circle.dotted" : "circle.slash",
            accessibilityDescription: enabled ? "ScreenGrain enabled" : "ScreenGrain disabled"
        )
        button.image?.isTemplate = true
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.refreshCaptureShortcutStatus()
            refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
