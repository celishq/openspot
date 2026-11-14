import Foundation

public struct SpotAction: Equatable, Sendable {
    private static let argumentLimit = 65_536

    public let arguments: [String]

    public static let open = SpotAction(arguments: ["open"])
    public static let read = SpotAction(arguments: ["read"])

    public init(arguments: [String]) {
        self.arguments = arguments
    }

    public static func toggle(_ state: SpotState) -> SpotAction {
        SpotAction(arguments: [state.control ?? "", (state.on ?? false) ? "false" : "true"])
    }

    public static func item(_ item: SpotItem) -> SpotAction {
        SpotAction(arguments: ["open", item.run])
    }

    public static func action(_ action: CommandAction, item: SpotItem?) -> SpotAction {
        SpotAction(arguments: [action.id] + (item.map { [$0.run] } ?? []))
    }

    public static func set(_ part: String, to value: String) -> SpotAction {
        SpotAction(arguments: [part, value])
    }

    public static func press(_ part: String) -> SpotAction {
        SpotAction(arguments: [part])
    }

    public static func drop(paths: [String]) -> SpotAction {
        SpotAction(arguments: ["drop"] + paths)
    }

    public static func drag(runs: [String]) -> SpotAction {
        SpotAction(arguments: ["drag"] + runs)
    }

    public func block(input: String? = nil, variables: [String: String] = [:], id: Int) -> String {
        let call = [TextBlock.Field(key: "call", value: String(id))] + arguments.map { TextBlock.Field(key: "arg", value: $0) }
        let env = variables.sorted { $0.key < $1.key }.map { TextBlock.Field(key: "env.\($0.key)", value: $0.value) }
        let stdin = input.flatMap { $0.isEmpty ? nil : [TextBlock.Field(key: "input", value: $0)] } ?? []
        return TextBlock(fields: call + env + stdin).text + "\n"
    }

    public static func stopEvent(id: Int) -> String {
        "stop=\(id)\n\n"
    }

    func sent(input: String?) -> (arguments: [String], input: String?) {
        let long = arguments.dropFirst().filter { $0.utf8.count > Self.argumentLimit }
        guard !long.isEmpty else { return (arguments, input) }
        let held = input.flatMap { TextBlock.blocks(in: $0).first }?.fields.map(\.value) ?? []
        let missing = long.filter { !held.contains($0) }.map { TextBlock.Field(key: "value", value: $0) }
        return (arguments.prefix(1) + arguments.dropFirst().filter { !long.contains($0) }, (input ?? "") + TextBlock(fields: missing).text)
    }

    public static func level(_ value: Double, of control: String) -> SpotAction {
        SpotAction(arguments: [control, String(Int(value.rounded()))])
    }
}
