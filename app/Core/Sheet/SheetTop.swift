import CoreGraphics
import Foundation

public struct SheetTop: Equatable, Sendable {
    public let header: CGFloat
    public let hasField: Bool

    public static let plain = SheetTop(header: 0, hasField: true)

    public init(header: CGFloat, hasField: Bool) {
        self.header = header
        self.hasField = hasField
    }

    public init(showsRows: Bool, search: ItemSearch, header: CGFloat) {
        self.init(header: header, hasField: showsRows && search != .off)
    }

    public var fieldY: CGFloat {
        SpotTokens.sheetFieldDrop + header
    }

    public var rowsTop: CGFloat {
        SpotTokens.sheetRowsTop + header - (hasField ? 0 : SpotTokens.listRow + SpotTokens.rowGap)
    }

    public var partsRoom: CGFloat {
        SpotTokens.partsMaxHeight - header - (hasField ? SpotTokens.partFieldRoom : 0)
    }

    public var listRoom: CGFloat {
        SpotTokens.listRoom - header
    }
}
