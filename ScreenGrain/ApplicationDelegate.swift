import AppKit

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusItemController(model: model)
        statusItemController = controller
        model.onChange = { [weak controller] in
            controller?.refresh()
        }
        model.start()
        controller.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}
