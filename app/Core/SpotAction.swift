import Foundation

public struct SpotAction: Equatable, Sendable {
    public let arguments: [String]

    public static let run = SpotAction(arguments: [])

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public static func toggle(_ state: SpotState) -> SpotAction {
        SpotAction(arguments: [(state.on ?? false) ? "off" : "on"])
    }

    public static func level(_ value: Double) -> SpotAction {
        SpotAction(arguments: [String(Int(value.rounded()))])
    }
}
