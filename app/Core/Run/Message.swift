import Foundation

public struct Message: Equatable, Sendable {
    public var handler: String
    public var inputs: [TextBlock.Field]
    public var given: String?
    public var settings: [TextBlock.Field]

    public init(_ handler: String, inputs: [TextBlock.Field] = [], given: String? = nil, settings: [TextBlock.Field] = []) {
        self.handler = handler
        self.inputs = inputs
        self.given = given
        self.settings = settings
    }

    public static func stopEvent(id: Int) -> String {
        "stop=\(id)\n\n"
    }

    public var text: String? {
        let settings = settings.map { TextBlock.Field(key: "setting.\($0.key)", value: $0.value) }
        let keys = inputs.map { TextBlock.Field(key: "input.\($0.key)", value: $0.value) }
        let text = TextBlock(fields: keys).text + (given ?? "") + TextBlock(fields: settings).text
        return text.isEmpty && given == nil ? nil : text
    }

    public func block(id: Int) -> String {
        let call = [TextBlock.Field(key: "call", value: String(id)), TextBlock.Field(key: "arg", value: handler)]
        let fields = text.map { TextBlock.blocks(in: $0).flatMap(\.fields) } ?? []
        return TextBlock(fields: call + fields).text + "\n"
    }
}
