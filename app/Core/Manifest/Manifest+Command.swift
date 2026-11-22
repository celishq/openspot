import Foundation

extension Manifest {
    public struct Command: Equatable, Sendable {
        public let id: String
        public let title: String
        public let icon: String?
        public let confirm: String?
        let section: String
        let close: Bool?
        let shortcut: String?
        let offers: [String]
        let hooks: [ActionHook: String]

        init(id: String, section: String, values: [String: [String]]) {
            let text = { (key: String) in values[key]?.first }
            self.id = id
            self.section = section
            title = text("title") ?? ""
            icon = text("icon")
            confirm = text("confirm")
            close = text("close").flatMap(Bool.init)
            shortcut = text("shortcut")
            offers = values["offers"] ?? []
            hooks = ActionHook.allCases.reduce(into: [:]) { hooks, hook in hooks[hook] = text(hook.rawValue) }
        }

        public var closes: Bool {
            close != false
        }
    }
}
