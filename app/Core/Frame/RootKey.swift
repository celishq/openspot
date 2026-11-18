public enum RootKey: String, CaseIterable, Sendable {
    case frame, grid, title, detail, active, recents, shown, progress
    case end, call

    public static let drawing = "grid."
    private static let names = Set(allCases.map(\.rawValue))
    static let marks: Set<String> = [end.rawValue, call.rawValue]
    static let appKeys: Set<String> = [shown.rawValue]

    static func isKey(_ key: String, isApp: Bool) -> Bool {
        (names.contains(key) && (isApp || !appKeys.contains(key))) || isDrawing(key)
    }

    static func isDrawing(_ key: String) -> Bool {
        key.hasPrefix(drawing)
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
