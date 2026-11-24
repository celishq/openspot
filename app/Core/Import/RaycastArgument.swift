import Foundation

public struct RaycastArgument: Equatable, Sendable {
    public struct Option: Equatable, Sendable {
        public let title: String
        public let value: String
    }

    public let placeholder: String
    public let isOptional: Bool
    public let isEncoded: Bool
    public let options: [Option]

    public init(placeholder: String, isOptional: Bool = false, isEncoded: Bool = false, options: [Option] = []) {
        self.placeholder = placeholder
        self.isOptional = isOptional
        self.isEncoded = isEncoded
        self.options = options
    }

    init?(json: String) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else { return nil }
        let options = (object["data"] as? [[String: Any]] ?? []).compactMap { item -> Option? in
            guard let value = Self.text(item["value"]) else { return nil }
            return Option(title: Self.text(item["title"]) ?? value, value: value)
        }
        if object["type"] as? String == "dropdown", options.isEmpty { return nil }
        self.init(
            placeholder: Self.text(object["placeholder"]) ?? "",
            isOptional: object["optional"] as? Bool ?? false,
            isEncoded: object["percentEncoded"] as? Bool ?? false,
            options: object["type"] as? String == "dropdown" ? options : []
        )
    }

    public var isChoice: Bool {
        !options.isEmpty
    }

    private static func text(_ value: Any?) -> String? {
        switch value {
        case let text as String: text
        case let number as NSNumber: number.stringValue
        default: nil
        }
    }
}
