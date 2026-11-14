public enum CalendarAccess: Sendable {
    case unasked
    case allowed
    case denied

    static let unaskedText = "status=unasked\n"
}
