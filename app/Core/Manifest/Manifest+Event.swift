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

        var check: InputCheck {
            InputCheck(owner: name, kind: .value, parameters: values)
        }
    }
}
