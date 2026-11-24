import Foundation

extension Manifest {
    public struct Binding: Equatable, Sendable {
        static let table = "bindings"
        static let spotKey = "spot"

        public let name: String
        public let spot: String

        init(name: String, value: ConfigDocument.Value?, section: String) throws {
            let fault = { (reason: String) in SpotError.fault("\(Manifest.fileName): \(section) \(name) \(reason)") }
            guard Setting.isKey(name), !name.contains(".") else { throw fault("needs a name with no space and no dot, such as picker = { spot = \"time-picker\" }.") }
            guard case .table(let fields)? = value else { throw fault("takes a table, such as \(name) = { spot = \"time-picker\" }.") }
            if let key = fields.keys.sorted().first(where: { $0 != Self.spotKey }) {
                throw fault("has an unknown key: \(key). Use spot.")
            }
            guard case .string(let spot)? = fields[Self.spotKey], !spot.isEmpty else {
                throw fault("needs the ID of a spot, such as \(name) = { spot = \"time-picker\" }.")
            }
            self.name = name
            self.spot = spot
        }

        var line: String {
            "\(name): \(spot)"
        }
    }
}
