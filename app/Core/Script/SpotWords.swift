import Foundation

public struct SpotWords: Equatable, Sendable {
    public let arguments: [String]

    public static let open = SpotWords(arguments: ["press"])
    public static let show = SpotWords(arguments: ["show"])

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public static func toggle(_ state: SpotState) -> SpotWords {
        SpotWords(arguments: [state.control ?? "", (state.on ?? false) ? "false" : "true"])
    }

    public static func item(_ item: SpotItem) -> SpotWords {
        item.isToggle ? SpotWords(arguments: [item.run, item.isOn ? "false" : "true"]) : SpotWords(arguments: ["press", item.run])
    }

    public static func action(_ action: CommandAction, item: SpotItem?) -> SpotWords {
        SpotWords(arguments: [CommandAction.command(of: action) ?? action.id] + (item.map { [$0.run] } ?? []))
    }

    public static func set(_ part: String, to value: String) -> SpotWords {
        SpotWords(arguments: [part, value])
    }

    public static func press(_ part: String) -> SpotWords {
        SpotWords(arguments: [part])
    }

    public static func drop(paths: [String]) -> SpotWords {
        SpotWords(arguments: ["drop"] + paths)
    }

    public static func drag(runs: [String]) -> SpotWords {
        SpotWords(arguments: ["drag"] + runs)
    }

    public static func stopEvent(id: Int) -> String {
        "stop=\(id)\n\n"
    }

    public static func level(_ value: Double, of control: String) -> SpotWords {
        SpotWords(arguments: [control, String(Int(value.rounded()))])
    }
}
