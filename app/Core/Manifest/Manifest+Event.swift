import Foundation

extension Manifest {
    public struct Event: Equatable, Sendable {
        static let table = "events"

        public let name: String
        public let values: [Parameter]

        init(name: String, section: String, table: ConfigDocument.Table) throws {
            guard Setting.isKey(name), !name.contains(".") else {
                throw SpotError.fault("\(Manifest.fileName): \(section) needs a name with no space and no dot, such as [events.snoozed].")
            }
            self.name = name
            values = try table.keys.map { key in
                guard Setting.isKey(key) else { throw SpotError.fault("\(Manifest.fileName): \(section) has a key with a space: \(key).") }
                return try Parameter(name: key, value: table[key], keys: Parameter.inputKeys, place: "\(section) \(key)")
            }
        }

        func values(_ given: [TextBlock.Field]) throws -> [TextBlock.Field] {
            if let unknown = given.first(where: { field in !values.contains { $0.name == field.key } }) {
                throw SpotError.fault("\(name) has no value \(unknown.key). Its values are: \(values.map(\.name).joined(separator: ", ")).")
            }
            var checked: [TextBlock.Field] = []
            for value in values {
                var texts = given.filter { $0.key == value.name && !$0.value.isEmpty }.map(\.value)
                if texts.isEmpty, let defaultValue = value.defaultValue { texts = [defaultValue] }
                if texts.isEmpty {
                    if value.isRequired { throw SpotError.fault("\(name) needs \(value.name), which is \(value.type.article).") }
                    continue
                }
                if let fault = value.fault(in: texts) { throw SpotError.fault("\(name) cannot be sent: \(fault).") }
                checked += texts.map { .init(key: value.name, value: $0) }
            }
            return checked
        }
    }
}
