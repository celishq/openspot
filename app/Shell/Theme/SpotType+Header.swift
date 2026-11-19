import AppKit
import OpenspotCore

extension SpotType {
    @MainActor static var sheetHeader: SheetHeader {
        let font = detailMeasure
        let twoLines = titleLine + lineGap + 2 * detailLine
        return SheetHeader(
            width: { ($0 as NSString).size(withAttributes: [.font: font]).width },
            secondLine: max(twoLines - max(titleLine + lineGap + detailLine, SpotTokens.glyph), 0)
        )
    }
}
