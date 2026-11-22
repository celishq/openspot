import Foundation

extension Manifest {
    public struct Setting: Equatable, Sendable {
        static let table = "settings"
        static let secret = "secret"

        public let id: String
        public let title: String
        public let icon: String?
        public let options: [String]
        public let defaultValue: String?
        public let valueType: ValueType?
        let section: String
        let type: String?

        init(id: String) {
            self.id = id
            section = ""
            title = id.prefix(1).uppercased() + id.dropFirst()
            icon = nil
            type = nil
            options = []
            defaultValue = nil
            valueType = nil
        }

        init(_ parameter: Parameter) {
            id = parameter.name
            section = "[\(Self.table)] \(parameter.name)"
            title = parameter.title ?? parameter.name.prefix(1).uppercased() + parameter.name.dropFirst()
            icon = parameter.icon
            type = parameter.type.name
            options = parameter.options
            defaultValue = parameter.defaultValue
            valueType = parameter.type
        }

        public var isSecret: Bool {
            type == Self.secret
        }

        static func isKey(_ id: String) -> Bool {
            !id.isEmpty && !id.contains(where: \.isWhitespace)
        }
    }
}
