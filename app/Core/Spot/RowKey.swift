public enum RowKey: String, CaseIterable, Sendable {
    case row, title, detail, icon, parent, tone, value, hides, keywords, shortcut, type, shake, pin, focus, open, close, file
    case push
    case pushSpot = "push.spot"
    case pushTitle = "push.title"
    case pushReplace = "push.replace"

    public static let hotkey = "hotkey"
}

