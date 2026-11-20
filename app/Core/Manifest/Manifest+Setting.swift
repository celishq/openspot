extension Manifest {
    public struct Setting: Equatable, Sendable {
        static let table = "settings"
        static let keys: Set<String> = ["title", "icon", "type", "options"]
        static let secret = "secret"

        public let id: String
        public let title: String
        public let icon: String?
        public let options: [String]
        let section: String
        let type: String?
        let unknownKey: String?

        init(id: String, section: String = "", values: [String: [String]] = [:], written: [String] = []) {
            self.id = id
            self.section = section
            title = values["title"]?.first ?? id.prefix(1).uppercased() + id.dropFirst()
            icon = values["icon"]?.first
            type = values["type"]?.first
            options = values["options"] ?? []
            unknownKey = written.first { !Self.keys.contains($0) }
        }

        public var isSecret: Bool {
            type == Self.secret
        }

        static func isKey(_ id: String) -> Bool {
            !id.isEmpty && !id.contains(where: \.isWhitespace)
        }
    }
}
