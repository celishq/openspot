import OpenspotCore
import ServiceManagement

/// The login item of this app.
enum AppLogin {
    /// The setting. macOS reports an app that was never registered as not found, so the setting does not ask before it registers.
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
