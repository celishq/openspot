import OpenspotCore
import ServiceManagement

/// The login item of this app.
enum AppLogin {
    /// The setting, when the Mac can find this app to register it. It asks the Mac once, because the answer takes a call to another process.
    static let item: LoginItem? = {
        guard SMAppService.mainApp.status != .notFound else { return nil }
        return LoginItem(
            isOn: { SMAppService.mainApp.status == .enabled },
            set: { isOn in
                if isOn {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            }
        )
    }()
}
