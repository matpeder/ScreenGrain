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
            "Move ScreenGrain to Applications before enabling Launch at Login."
        default:
            nil
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }
}

