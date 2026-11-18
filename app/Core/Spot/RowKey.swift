public enum RowKey: String, CaseIterable, Sendable {
    case row, title, detail, icon, parent, tone, value, max, section, hides, keywords, shortcut, type, shake, pin, focus, open, close, file
    case route
    case routeTitle = "route.title"
    case routeReplace = "route.replace"

    public static let hotkey = "hotkey"
    public static let toggle = "toggle"
}

