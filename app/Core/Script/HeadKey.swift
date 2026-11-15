public enum HeadKey: String, CaseIterable, Sendable {
    case grid, main, title, detail, active, recents, search, shown
    case toast, link, progress, select
    case push
    case pushSpot = "push.spot"
    case pushTitle = "push.title"
    case pushReplace = "push.replace"
    case pop, end, call

    public static let drawing = "grid."

    private static let names = Set(allCases.map(\.rawValue))

    static func isKey(_ key: String) -> Bool {
        names.contains(key) || key.hasPrefix(drawing)
    }
}
