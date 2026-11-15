import AppKit
import OpenspotCore

@MainActor
enum SpotWordsWidth {
    private static var widths = RecentCache<String, CGFloat>(limit: 4 << 10)

    static func of(title: String, detail: String?) -> CGFloat {
        let key = "\(title)\n\(detail ?? "")"
        if let width = widths.value(for: key) { return width }
        let width = max(
            (title as NSString).size(withAttributes: [.font: SpotType.titleMeasure]).width,
            ((detail ?? "") as NSString).size(withAttributes: [.font: SpotType.detailMeasure]).width
        )
        widths.keep(width, for: key, cost: key.utf8.count)
        return width
    }
}
