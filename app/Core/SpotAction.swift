import Foundation

public struct SpotAction: Equatable, Sendable {
    public let arguments: [String]

    public static let run = SpotAction(arguments: [])
    public static let read = SpotAction(arguments: ["state"])

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public static func items(query: String) -> SpotAction {
        SpotAction(arguments: query.isEmpty ? ["items"] : ["items", query])
    }

    public static func toggle(_ state: SpotState) -> SpotAction {
        SpotAction(arguments: [(state.on ?? false) ? "off" : "on"])
    }

    public static func item(_ item: SpotItem) -> SpotAction {
        SpotAction(arguments: [item.run])
    }

    public static func level(_ value: Double) -> SpotAction {
        SpotAction(arguments: [String(Int(value.rounded()))])
    }
}
