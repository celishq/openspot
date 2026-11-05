import Foundation

public struct SpotAction: Equatable, Sendable {
    public let arguments: [String]

    public static let run = SpotAction(arguments: [])
    public static let read = SpotAction(arguments: [])

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public static func items(query: String) -> SpotAction {
        SpotAction(arguments: query.isEmpty ? [] : ["search", query])
    }

    public static func toggle(_ state: SpotState) -> SpotAction {
        SpotAction(arguments: [(state.on ?? false) ? "off" : "on"])
    }

    public static func item(_ item: SpotItem) -> SpotAction {
        SpotAction(arguments: ["open", item.run])
    }

    public static func action(_ action: CommandAction, item: SpotItem?) -> SpotAction {
        SpotAction(arguments: [action.id] + (item.map { [$0.run] } ?? []))
    }

    public static func form(_ action: CommandAction, item: SpotItem?) -> SpotAction {
        SpotAction(arguments: ["form", action.id] + (item.map { [$0.run] } ?? []))
    }

    public static func level(_ value: Double) -> SpotAction {
        SpotAction(arguments: ["level", String(Int(value.rounded()))])
    }
}
