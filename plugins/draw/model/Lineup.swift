import CoreGraphics
import Foundation

/// The rows of the list that stay while a drag carries others, one after another by their heights, and where the
/// carried rows would land for a pointer this far down. The gap that opens where they would land is taken out first, so
/// the gap never moves under a still pointer.
struct Lineup {
    struct Row: Equatable {
        let url: URL
        let isFolder: Bool
        /// Whether the folder shows what it holds, and the first row it holds.
        var open = false
        var first: URL?
        let height: CGFloat
    }

    /// Where carried rows would land: inside a folder, or in a folder before a row, or at the folder's end.
    enum Landing: Equatable {
        case into(URL)
        case before(URL?, in: URL)
    }

    let rows: [Row]
    /// The folder at the top of the list.
    let top: URL
    var spacing: CGFloat = 2

    /// Where the rows would land, with the gap open before `gap` (nil for the end) and `gapHeight` tall.
    func landing(at y: CGFloat, gap: URL??, gapHeight: CGFloat) -> Landing {
        var start: CGFloat = 0
        var gapTop: CGFloat?
        for row in rows {
            if gap == .some(row.url) { gapTop = start }
            start += row.height + spacing
        }
        if gap == .some(nil) { gapTop = start }
        let flat = gapTop.map { y > $0 ? max($0, y - gapHeight) : y } ?? y
        start = 0
        for (index, row) in rows.enumerated() {
            if flat < start + row.height + spacing {
                let parent = Self.parent(of: row.url)
                if row.isFolder, flat > start + row.height * 0.25, flat < start + row.height * 0.75 { return .into(row.url) }
                if flat < start + row.height / 2 { return .before(row.url, in: parent) }
                if row.isFolder, row.open { return .before(row.first, in: row.url) }
                let next = rows[(index + 1)...].first
                return .before(next.map { Self.parent(of: $0.url) == parent } == true ? next?.url : nil, in: parent)
            }
            start += row.height + spacing
        }
        return .before(nil, in: top)
    }

    /// The folder that holds a row, written the same way as a folder's own place.
    static func parent(of url: URL) -> URL {
        URL(fileURLWithPath: url.deletingLastPathComponent().path)
    }
}
