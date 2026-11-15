public enum HeaderKey: String, CaseIterable, Sendable {
    case title, icon, detail, keywords, on, emits, offers, drop, edits, view, mode, press, uses, pages, to

    public static let drawing = "grid."

    static let card: Set<HeaderKey> = [.title, .icon, .detail, .keywords, .to]

    static func isDrawing(_ key: String) -> Bool {
        key.hasPrefix(drawing)
    }

    static func unknown(in header: TextBlock) -> String? {
        header.fields.map(\.key).first { HeaderKey(rawValue: $0) == nil && !isDrawing($0) }
    }
}
