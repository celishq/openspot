public enum ItemKey: String, CaseIterable, Sendable {
    case title, detail, icon, tone, value, parent, keywords, pin, hides, file, close, shake, form
    case openTitle = "open.title"
    case openWait = "open.wait"
    case route
    case routeTitle = "route.title"
    case routeReplace = "route.replace"
}
