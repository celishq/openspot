import Foundation

public enum SpotTokens {
    nonisolated(unsafe) public private(set) static var layout = Theme.Layout()

    public static func take(_ next: Theme.Layout) {
        if next != layout { layout = next }
    }

    public static var cardRadius: CGFloat { layout.radius.card }
    public static var columnGap: CGFloat { layout.space.columnGap }
    public static var rowGap: CGFloat { layout.space.rowGap }
    public static var padding: CGFloat { layout.space.padding }
    public static var gridWidth: CGFloat { layout.gridWidth }
    public static let columns = 4
    public static let rows = 7
    public static var cell: CGFloat { layout.space.cell }
    public static var glyph: CGFloat { layout.space.glyph }
    public static let glyphInset: CGFloat = 9
    public static let workMark: CGFloat = 16
    public static let cornerMark: CGFloat = 20
    public static var cornerMarkRadius: CGFloat { layout.radius.cornerMark }
    public static let ring: CGFloat = 2
    public static let thinRing: CGFloat = 1.5
    public static let resizeHandle: CGFloat = 28
    public static let resizeHandleLine: CGFloat = 5
    public static let toastGap: CGFloat = 10
    public static var listRow: CGFloat { layout.space.listRow }
    public static var listRowGap: CGFloat { layout.space.listRowGap }
    public static let listIconSize: CGFloat = 24
    public static let hintHeight: CGFloat = 14
    public static let hintPillInset: CGFloat = 4
    public static let hintKeyHeight: CGFloat = 16
    public static let hintKeyPadding: CGFloat = 5
    public static let hintKeyGap: CGFloat = 4
    public static let hintGroupGap: CGFloat = 12
    public static let hintEndPadding: CGFloat = 10
    public static var menuRow: CGFloat { layout.space.menuRow }
    public static let menuRowGap: CGFloat = 2
    public static var menuPadding: CGFloat { layout.space.menuPadding }
    public static let placeGap: CGFloat = 8
    public static let edgeWidth: CGFloat = 8
    public static let edgeGap: CGFloat = 8
    public static let edgeStep: CGFloat = 5
    public static let edgeShrink: CGFloat = 28
    public static let edgeCount = 3
    public static let edgeRest: Duration = .milliseconds(250)
    public static let swipeDistance: CGFloat = 60
    public static let controlPadding: CGFloat = 7
    public static let focusGap: CGFloat = 4
    public static let formLabelHeight: CGFloat = 14
    public static let formLabelGap: CGFloat = 4
    public static let formFieldGap: CGFloat = 12
    public static let formTextHeight: CGFloat = 120
    public static let halo: CGFloat = 90
    public static let pinRuleRoom: CGFloat = 9
    public static let windowColumns = 16
    public static let windowMinSize = CGSize(width: 360, height: 280)
    public static let editorInset: CGFloat = 5
    public static var windowRadius: CGFloat { layout.radius.window }
    public static let windowHeight: CGFloat = 760
    public static let pictureShare: CGFloat = 0.6
    public static let spaceUnit: CGFloat = 4
}
