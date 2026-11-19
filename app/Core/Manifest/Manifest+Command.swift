extension Manifest {
    public struct Command: Equatable, Sendable {
        static let table = "commands"
        static let keys = Set(["title", "icon", "offers", "shortcut", "scope", "close", "form", "confirm", "placeholder"] + ActionHook.allCases.map(\.rawValue))

        public let id: String
        public let title: String
        public let icon: String?
        public let confirm: String?
        public let placeholder: String?
        let section: String
        let close: Bool?
        let form: Bool?
        let scope: String?
        let shortcut: String?
        let offers: [String]
        let hooks: [ActionHook: String]
        let unknownKey: String?

        init(id: String, section: String, values: [String: [String]], written: [String]) {
            let text = { (key: String) in values[key]?.first }
            self.id = id
            self.section = section
            title = text("title") ?? ""
            icon = text("icon")
            confirm = text("confirm")
            placeholder = text("placeholder")
            close = text("close").flatMap(Bool.init)
            form = text("form").flatMap(Bool.init)
            scope = text("scope")
            shortcut = text("shortcut")
            offers = values["offers"] ?? []
            hooks = ActionHook.allCases.reduce(into: [:]) { hooks, hook in hooks[hook] = text(hook.rawValue) }
            unknownKey = written.first { !Self.keys.contains($0) }
        }

        public var closes: Bool {
            close != false
        }
    }
}
