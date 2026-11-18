public enum HeaderKey: String, CaseIterable, Sendable {
    case title, icon, detail, keywords, placeholder, on, emits, offers, drop, edits, starts, view, source, mode, press, uses, pages, to, answers

    public static let drawing = "grid."

    static let card: Set<HeaderKey> = [.title, .icon, .detail, .keywords, .to]

    static func isDrawing(_ key: String) -> Bool {
        key.hasPrefix(drawing)
    }

    static func isWord(_ key: String) -> Bool {
        !key.isEmpty && key.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "." || $0 == "-" }
    }

    static func unknown(in header: TextBlock) -> String? {
        header.fields.map(\.key).first { isWord($0) && HeaderKey(rawValue: $0) == nil && !isDrawing($0) }
    }
}
