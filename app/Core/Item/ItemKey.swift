public enum ItemKey: String, CaseIterable, Sendable {
    case title, detail, icon, tone, value, place, keywords, pin, hides, file, close, shake
    case openTitle = "open.title"
    case openWait = "open.wait"
    case chosen
    case route
    case routeTitle = "route.title"
    case routeReplace = "route.replace"
}
