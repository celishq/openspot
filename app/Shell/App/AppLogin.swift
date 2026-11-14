import OpenspotCore
import ServiceManagement

enum AppLogin {
    static let item = LoginItem(
        isOn: { SMAppService.mainApp.status == .enabled },
        set: { isOn in
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
    )
}
