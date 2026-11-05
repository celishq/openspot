import Carbon.HIToolbox
import Foundation
import OpenspotCore

/// A key that arms the commands: for a short time, each command's own key runs it from any app, and Escape cancels.
@MainActor
final class CommandTrigger {
    private static let window: TimeInterval = 3

    private let model: SpotsModel
    private let toast: ToastPanel
    private var registrations: [HotKey.Registration] = []
    private var armings = 0

    init(model: SpotsModel, toast: ToastPanel) {
        self.model = model
        self.toast = toast
    }

    func press() {
        if registrations.isEmpty {
            arm()
        } else {
            disarm()
        }
    }

    private func arm() {
        let keyed = model.entries.filter { $0.command.key != nil }
        guard !keyed.isEmpty else {
            toast.show("No command has a key yet.")
            return
        }
        for entry in keyed {
            guard let key = entry.command.key else { continue }
            let id = entry.id
            register(code: key.code) { trigger in
                trigger.disarm()
                trigger.model.press(id)
            }
        }
        register(code: UInt32(kVK_Escape)) { $0.disarm() }
        let list = keyed.compactMap { entry in entry.command.key.map { "\($0.name.uppercased()) \(entry.command.name)".replacingOccurrences(of: " ", with: "\u{00A0}") } }
        toast.show(list.joined(separator: " · "), symbol: "command", for: Self.window)
        armings += 1
        let arming = armings
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.window) {
            if self.armings == arming, !self.registrations.isEmpty { self.disarm() }
        }
    }

    private func disarm() {
        registrations.forEach(HotKey.unregister)
        registrations = []
        armings += 1
        toast.hide()
    }

    private func register(code: UInt32, action: @escaping @MainActor (CommandTrigger) -> Void) {
        let registration = HotKey.register(code: code, modifiers: 0) { [weak self] in
            Task { @MainActor in
                if let self { action(self) }
            }
        }
        if let registration { registrations.append(registration) }
    }
}
