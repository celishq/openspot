public enum RootKey: String, CaseIterable, Sendable {
    case frame, title, detail, active, recents, shown, progress, value, type, background, builds
    case end, call, error
    case classes = "class"

    static let form = "form"
    static let outputPrefix = "out."

    private static let names = Set(allCases.map(\.rawValue))
    static let marks: Set<String> = [end.rawValue, call.rawValue]
    static let appKeys: Set<String> = [shown.rawValue, builds.rawValue]

    static func isKey(_ key: String, isApp: Bool) -> Bool {
        names.contains(key) && (isApp || !appKeys.contains(key)) || key.hasPrefix(outputPrefix)
    }

    static func block(_ fields: [TextBlock.Field]) -> TextBlock {
        TextBlock(fields: [.init(key: frame.rawValue, value: "")] + fields)
    }

    static func starts(_ block: TextBlock) -> Bool {
        guard let key = block.fields.first?.key else { return false }
        return key == frame.rawValue || key == error.rawValue || key.hasPrefix(outputPrefix)
    }

    static func isMark(_ block: TextBlock) -> Bool {
        block.fields.first.map { marks.contains($0.key) } ?? false
    }
}
