import AppKit

/// The width of a header's words as they are drawn, the longer of the title and the second line, measured once for each
/// pair of words. It keeps at most 64 pairs.
@MainActor
enum SpotWordsWidth {
    private static let limit = 64
    private static var widths: [String: CGFloat] = [:]

    static func of(title: String, detail: String?) -> CGFloat {
        let key = "\(title)\n\(detail ?? "")"
        if let width = widths[key] { return width }
        let width = max(
            (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).width,
            ((detail ?? "") as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width
        )
        if widths.count >= limit { widths = [:] }
        widths[key] = width
        return width
    }
}
