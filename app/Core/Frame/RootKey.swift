public enum RootKey: String, CaseIterable, Sendable {
    case frame, title, detail, active, recents, shown, progress
    case end, call
    case classes = "class"

    private static let names = Set(allCases.map(\.rawValue))
    static let marks: Set<String> = [end.rawValue, call.rawValue]
    static let appKeys: Set<String> = [shown.rawValue]

    static func isKey(_ key: String, isApp: Bool) -> Bool {
        names.contains(key) && (isApp || !appKeys.contains(key))
    }

    static func block(_ fields: [TextBlock.Field]) -> TextBlock {
        TextBlock(fields: [.init(key: frame.rawValue, value: "")] + fields)
    }

    static func starts(_ block: TextBlock) -> Bool {
        block.fields.first?.key == frame.rawValue
    }

    static func isMark(_ block: TextBlock) -> Bool {
        block.fields.first.map { marks.contains($0.key) } ?? false
    }
}
