import Foundation
import CoreGraphics

public enum SheetFaults {
    private static let letterWidth: CGFloat = 6.5
    private static let detailLetterWidth: CGFloat = 5.5
    private static let controlWidth: CGFloat = 52
    private static let metricWidth: CGFloat = 100
    private static let tallMetric: CGFloat = 60
    private static let tallProgress: CGFloat = 44
    private static let swatchWidth: CGFloat = 26
    private static let smallSwatchWidth: CGFloat = 18

    public static func of(layout: SheetLayout?, summary: TextBlock?, parts: [SpotPart]) -> [String] {
        var faults: [String] = []
        if summary?.value("layout") != nil { faults.append("a sheet has no layout key, so draw it with grid= lines") }
        if summary?.value("card") != nil { faults.append("a sheet has no card key, so leave it out: each part draws its own box") }
        if summary?.value("pad") != nil { faults.append("a sheet has no pad key, so print a button for each key") }
        guard let layout, layout.isDrawn else {
            let flat = SheetPlacement(parts: parts, layout: SheetLayout(flat: parts))
            if flat.overflows, parts.contains(where: \.scrollsItself) {
                faults.append("the sheet is too tall for a part that scrolls: \(Int(flat.height))pt of \(Int(SheetPlacement.maxHeight))pt")
            }
            return faults
        }
        if Set(layout.rows.map(\.count)).count > 1 { faults.append("each grid line needs the same number of columns") }
        faults += letterFaults(layout, parts)
        faults += repeatFaults(layout, parts)
        for (index, row) in layout.rows.enumerated() where row.contains(SheetLayout.divider) {
            if row.filter({ $0 != SheetLayout.divider }).count > 1 { faults.append("the divider in row \(index + 1) is not whole") }
        }
        if parts.filter({ $0.look == .strong }).count > 1 { faults.append("only one part can use look=strong") }
        let letters = layout.areas.keys.sorted()
        for (index, first) in letters.enumerated() {
            for second in letters[(index + 1)...] {
                guard let a = layout.areas[first], let b = layout.areas[second], a.hits(b), a.size == b.size else { continue }
                faults.append("\(first) and \(second) overlap at one size, so neither lies on top")
            }
        }
        faults += sizeFaults(layout, parts)
        return faults
    }

    private static func letterFaults(_ layout: SheetLayout, _ parts: [SpotPart]) -> [String] {
        var faults: [String] = []
        var taken = Set<String>()
        for part in parts {
            guard let letter = layout.letter(of: part) else { continue }
            if layout.areas[letter] == nil { faults.append("the part \(part.id) is not in the drawing") }
            if !taken.insert(part.id).inserted { faults.append("two parts are called \(part.id)") }
        }
        return faults
    }

    private static func repeatFaults(_ layout: SheetLayout, _ parts: [SpotPart]) -> [String] {
        guard let repeated = layout.repeated else { return [] }
        var faults: [String] = []
        if layout.repeatCount > 1 { faults.append("a sheet can repeat only one area") }
        if layout.areas[repeated.area] == nil { faults.append("the repeat names \(repeated.area), which the drawing does not have") }
        for part in parts where layout.letter(of: part) == repeated.area {
            faults.append("the part \(part.id) stands on the repeated area \(repeated.area)")
        }
        return faults
    }

    private static func sizeFaults(_ layout: SheetLayout, _ parts: [SpotPart]) -> [String] {
        let sheet = SheetPlacement(parts: parts, layout: layout)
        let columns = max(layout.rows.map(\.count).max() ?? 1, 1)
        let columnWidth = (SheetPlacement.width - SheetPlacement.gap * CGFloat(columns - 1)) / CGFloat(columns)
        var faults: [String] = []
        for part in parts {
            guard let letter = layout.letter(of: part), let area = layout.areas[letter], let frame = sheet.frames[part.id] else { continue }
            let width = CGFloat(area.x1 - area.x0 + 1) * (columnWidth + SheetPlacement.gap) - SheetPlacement.gap
            let height = frame.isOnTop ? CGFloat.infinity : frame.rect.height
            switch part.control {
            case .number:
                if width < metricWidth {
                    faults.append("the part \(part.id) needs at least \(Int((metricWidth + SheetPlacement.gap) / (columnWidth + SheetPlacement.gap)) + 1) columns of \(columns) for its number")
                }
                if part.title != nil, height < tallMetric { faults.append("the part \(part.id) needs at least 2 rows for its number and title") }
            case .progress:
                if height < tallProgress { faults.append("the part \(part.id) needs at least 2 rows for its title and bar") }
            case .swatches(let colors, _):
                if colors.count > 1, CGFloat(colors.count) * swatchWidth > width + SheetPlacement.gap { faults.append("the part \(part.id) needs more columns for its \(colors.count) colours") }
            default:
                break
            }
            if let title = part.title, !part.fillsHeight {
                var control = part.control == .none && part.press != .line ? 0 : controlWidth
                if case .swatches = part.control { control = smallSwatchWidth }
                let detail = frame.hasDetailUnderTitle ? 0 : part.detail.map { CGFloat($0.count) * detailLetterWidth + 2 * SheetPlacement.gap } ?? 0
                if CGFloat(title.count) * letterWidth + detail + (part.press == .line ? 0 : control) > width {
                    faults.append("the title of the part \(part.id) may not fit its cell")
                }
            }
            if !frame.isOnTop, !part.fillsHeight, frame.rect.height > SheetPlacement.rowHeight * 2, area.y0 == area.y1 {
                faults.append("the part \(part.id) sits in rows that stretch, so draw a choice over two lines for a list")
            }
        }
        if sheet.overflows {
            faults.append("the drawing is too tall: \(Int(sheet.height))pt of \(Int(SheetPlacement.maxHeight))pt")
        }
        return faults
    }
}
