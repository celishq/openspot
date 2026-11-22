import Foundation
import CoreGraphics

public enum SheetFaults {
    public static func of(parts: [SpotPart]) -> [String] {
        let flat = SheetPlacement(parts: parts, layout: SheetLayout(flat: parts))
        guard flat.overflows, parts.contains(where: \.scrollsItself) else { return [] }
        return ["the sheet is too tall for a part that scrolls: \(Int(flat.height))pt of \(Int(SpotTokens.partsMaxHeight))pt"]
    }
}
