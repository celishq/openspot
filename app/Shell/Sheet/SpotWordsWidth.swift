import AppKit

/// The width of a header's words as they are drawn, the longer of the title and the second line, measured once for each
/// pair of words. It keeps at most 4 KB of words, and starts again when it would hold more.
@MainActor
enum SpotWordsWidth {
    private static let byteLimit = 4 << 10
    private static var widths: [String: CGFloat] = [:]
    private static var bytes = 0

    static func of(title: String, detail: String?) -> CGFloat {
        let key = "\(title)\n\(detail ?? "")"
        if let width = widths[key] { return width }
        let width = max(
            (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).width,
            ((detail ?? "") as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width
        )
        if bytes + key.utf8.count > byteLimit {
            widths = [:]
            bytes = 0
        }
        widths[key] = width
        bytes += key.utf8.count
        return width
    }
}
