import CoreGraphics
import Foundation

public struct SheetHeader {
    @MainActor public static var shared = SheetHeader(width: { _ in 0 }, secondLine: 0)

    let width: (String) -> CGFloat
    let secondLine: CGFloat

    public init(width: @escaping (String) -> CGFloat, secondLine: CGFloat) {
        self.width = width
        self.secondLine = secondLine
    }

    public func extra(for detail: String?) -> CGFloat {
        guard let detail, width(detail) > SpotTokens.sheetWordsWidth else { return 0 }
        return secondLine
    }
}
