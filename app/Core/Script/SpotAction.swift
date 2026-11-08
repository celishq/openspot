import Foundation

public struct SpotAction: Equatable, Sendable {
    private static let argumentLimit = 65_536

    public let arguments: [String]

    public static let run = SpotAction(arguments: ["run"])
    public static let read = SpotAction(arguments: ["read"])

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    /// A read for the text of a search, followed by each other form of it that the person may have meant.
    public static func items(query: String, forms: [String] = []) -> SpotAction {
        SpotAction(arguments: query.isEmpty ? ["read"] : ["read", query] + forms)
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

    /// A person set the value of a part.
    public static func set(_ part: String, to value: String) -> SpotAction {
        SpotAction(arguments: [part, value])
    }

    /// A person changed or pressed a slot of a row: `<slot> <run> [value]` (U9).
    public static func slot(_ slot: String, run: String, value: String? = nil) -> SpotAction {
        SpotAction(arguments: [slot, run] + (value.map { [$0] } ?? []))
    }

    /// A person pressed a part.
    public static func press(_ part: String) -> SpotAction {
        SpotAction(arguments: [part])
    }

    /// A person dropped or chose files on a card. Each path is its own argument.
    public static func drop(paths: [String]) -> SpotAction {
        SpotAction(arguments: ["drop"] + paths)
    }

    /// What a process gets for this call. A value over 64 KB leaves the arguments, because the system limits them. Stdin
    /// holds it: a value of the sheet as it is, and any other value under the key `value`.
    func sent(input: String?) -> (arguments: [String], input: String?) {
        let long = arguments.dropFirst().filter { $0.utf8.count > Self.argumentLimit }
        guard !long.isEmpty else { return (arguments, input) }
        let held = input.flatMap { TextBlock.blocks(in: $0).first }?.fields.map(\.value) ?? []
        let missing = long.filter { !held.contains($0) }.map { TextBlock.Field(key: "value", value: $0) }
        return (arguments.prefix(1) + arguments.dropFirst().filter { !long.contains($0) }, (input ?? "") + TextBlock(fields: missing).text)
    }

    public static func level(_ value: Double) -> SpotAction {
        SpotAction(arguments: ["level", String(Int(value.rounded()))])
    }
}
