import Foundation

public struct SpotWords: Equatable, Sendable {
    public let arguments: [String]

    public static let open = SpotWords(arguments: ["press"])
    public static let show = SpotWords(arguments: ["show"])

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public static func item(_ item: SpotItem) -> SpotWords {
        item.isToggle ? SpotWords(arguments: [item.run, item.isOn ? "false" : "true"]) : SpotWords(arguments: ["press", item.run])
    }

    public static func action(_ action: CommandAction, item: SpotItem?) -> SpotWords {
        SpotWords(arguments: [action.callName] + (item.map { [$0.run] } ?? []))
    }

    public static func press(_ part: String) -> SpotWords {
        SpotWords(arguments: [part])
    }

    public static func stopEvent(id: Int) -> String {
        "stop=\(id)\n\n"
    }
}
