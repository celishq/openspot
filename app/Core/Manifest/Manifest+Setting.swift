import Foundation

extension Manifest {
    public struct Setting: Equatable, Sendable {
        static let table = "settings"

        public let parameter: Parameter

        init(_ parameter: Parameter) {
            self.parameter = parameter
        }

        init(id: String) {
            parameter = Parameter(name: id, type: ValueType(.text), isRequired: false)
        }

        public var id: String {
            parameter.name
        }

        public var title: String {
            parameter.title ?? id.prefix(1).uppercased() + id.dropFirst()
        }

        public var icon: String? {
            parameter.icon
        }

        public var options: [String] {
            parameter.options
        }

        public var defaultValue: String? {
            parameter.defaultValue
        }

        public var isSecret: Bool {
            parameter.type == ValueType(.secret)
        }

        var section: String {
            "[\(Self.table)] \(id)"
        }

        static func isKey(_ id: String) -> Bool {
            !id.isEmpty && !id.contains(where: \.isWhitespace)
        }
    }
}
