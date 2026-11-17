import Foundation

public struct SpotSizes: Equatable, Sendable {
    public let cell: CGFloat
    public let columnGap: CGFloat
    public let rowGap: CGFloat
    public let padding: CGFloat
    public let glyph: CGFloat
    public let listRow: CGFloat
    public let listRowGap: CGFloat
    public let menuRow: CGFloat
    public let menuPadding: CGFloat
    public let cardRadius: CGFloat
    public let windowRadius: CGFloat
    public let mediaRadius: CGFloat
    public let cornerMarkRadius: CGFloat
    public let gridWidth: CGFloat
    public let panelWidth: CGFloat
    public let panelHeight: CGFloat
    public let hintBlock: CGFloat
    public let sheetMaxHeight: CGFloat
    public let sheetFieldDrop: CGFloat
    public let sheetRowsTop: CGFloat
    public let gridTop: CGFloat
    public let partsWidth: CGFloat
    public let backdrop: Theme.Backdrop
    public let backdropEdges: [BackdropEdge]

    public init(_ layout: Theme.Layout) {
        let space = layout.space
        cell = space.cell
        columnGap = space.columnGap
        rowGap = space.rowGap
        padding = space.padding
        glyph = space.glyph
        listRow = space.listRow
        listRowGap = space.listRowGap
        menuRow = space.menuRow
        menuPadding = space.menuPadding
        cardRadius = layout.radius.card
        windowRadius = layout.radius.window
        mediaRadius = layout.radius.media
        cornerMarkRadius = layout.radius.cornerMark
        let columns = CGFloat(SpotTokens.columns)
        let halo = SpotTokens.halo
        gridWidth = columns * cell + (columns - 1) * columnGap
        panelWidth = gridWidth + 2 * halo
        hintBlock = rowGap + SpotTokens.hintPillHeight
        panelHeight = 2 * halo + 7 * cell + 6 * rowGap + hintBlock
        sheetMaxHeight = panelHeight - 2 * halo - hintBlock
        sheetFieldDrop = padding + glyph + rowGap
        sheetRowsTop = sheetFieldDrop + listRow + rowGap
        gridTop = halo + cell + rowGap
        partsWidth = gridWidth - 2 * padding
        backdrop = layout.backdrop
        backdropEdges = BackdropEdge.edges(of: layout.backdrop)
    }
}
