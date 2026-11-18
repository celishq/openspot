public enum RootKey: String, CaseIterable, Sendable {
    case frame, grid, title, detail, active, recents, shown, progress
    case end, call

    private static let names = Set(allCases.map(\.rawValue))
    static let marks: Set<String> = [end.rawValue, call.rawValue]

    static func isKey(_ key: String) -> Bool {
        names.contains(key) || HeaderKey.isDrawing(key)
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
