import AppKit
import OpenspotCore

@MainActor
enum SpotWordsWidth {
    private static var widths = RecentCache<String, CGFloat>(base: 4 << 10)

    static func of(title: String, detail: String?) -> CGFloat {
        let key = "\(title)\n\(detail ?? "")"
        if let width = widths.value(for: key) { return width }
        let width = max(
            (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).width,
            ((detail ?? "") as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width
        )
        widths.keep(width, for: key, cost: key.utf8.count)
        return width
    }
}
