import ServiceManagement

struct LoginItemService {
    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    var message: String? {
        switch status {
        case .requiresApproval:
            "Allow ScreenGrain in System Settings › General › Login Items."
        case .notFound:
            "Launch at Login registration is unavailable for this build."
        default:
            nil
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if status != .enabled, status != .requiresApproval {
                try SMAppService.mainApp.register()
            }
        } else if status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }
}
