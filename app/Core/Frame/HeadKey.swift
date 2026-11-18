public enum HeadKey: String, CaseIterable, Sendable {
    case grid, main, title, detail, active, recents, search, shown
    case toast, link, progress, select, slash
    case push
    case pushSpot = "push.spot"
    case pushTitle = "push.title"
    case pushReplace = "push.replace"
    case pop, end, call

    private static let names = Set(allCases.map(\.rawValue))

    static func isKey(_ key: String) -> Bool {
        names.contains(key) || HeaderKey.isDrawing(key)
    }
}
