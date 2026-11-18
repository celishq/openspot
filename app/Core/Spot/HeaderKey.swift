public enum HeaderKey: String, CaseIterable, Sendable {
    case title, icon, detail, keywords, placeholder, on, emits, offers, drop, edits, starts, view, source, mode, uses, pages, answers

    public static let drawing = "grid."

    static func isDrawing(_ key: String) -> Bool {
        key.hasPrefix(drawing)
    }

    static func unknown(in header: TextBlock) -> String? {
        header.fields.map(\.key).first { HeaderKey(rawValue: $0) == nil }
    }
}
