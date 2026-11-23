import Foundation

public struct Message: Equatable, Sendable {
    static let argumentLimit = 65_536

    public var words: SpotWords
    public var inputs: [TextBlock.Field]
    public var given: String?
    public var settings: [TextBlock.Field]

    public init(_ words: SpotWords, inputs: [TextBlock.Field] = [], given: String? = nil, settings: [TextBlock.Field] = []) {
        self.words = words
        self.inputs = inputs
        self.given = given
        self.settings = settings
    }

    public var text: String? {
        let settings = settings.map { TextBlock.Field(key: "setting.\($0.key)", value: $0.value) }
        let keys = inputs.map { TextBlock.Field(key: "input.\($0.key)", value: $0.value) }
        let text = TextBlock(fields: keys).text + (given ?? "") + TextBlock(fields: settings).text
        return text.isEmpty && given == nil ? nil : text
    }

    public func block(id: Int) -> String {
        let call = [TextBlock.Field(key: "call", value: String(id))] + words.arguments.map { TextBlock.Field(key: "arg", value: $0) }
        let fields = text.map { TextBlock.blocks(in: $0).flatMap(\.fields) } ?? []
        return TextBlock(fields: call + fields).text + "\n"
    }

    var sent: (arguments: [String], input: String?) {
        let arguments = words.arguments
        let input = text
        let long = arguments.dropFirst().filter { $0.utf8.count > Self.argumentLimit }
        guard !long.isEmpty else { return (arguments, input) }
        let held = input.flatMap { TextBlock.blocks(in: $0).first }?.fields.map(\.value) ?? []
        let missing = long.filter { !held.contains($0) }.map { TextBlock.Field(key: "input.value", value: $0) }
        return (arguments.prefix(1) + arguments.dropFirst().filter { !long.contains($0) }, (input ?? "") + TextBlock(fields: missing).text)
    }
}
