public enum HeaderKey: String, CaseIterable, Sendable {
    case title, icon, detail, keywords, placeholder, on, emits, offers, drop, edits, starts, view, source, mode, uses, pages, answers

    public static let drawing = "grid."

    static func isDrawing(_ key: String) -> Bool {
        key.hasPrefix(drawing)
    }

    static let ofTheApp: Set<HeaderKey> = [.edits]

    static func unknown(in header: TextBlock, isApp: Bool = false) -> String? {
        header.fields.map(\.key).first { key in HeaderKey(rawValue: key).map { !isApp && ofTheApp.contains($0) } ?? true }
    }
}
