import Foundation

public struct ViewTheme {
    public let values: [String: Any]

    public init<Colour, Face>(
        layout: Theme.Layout, look: Theme.Appearance, corner: CGFloat,
        colour: (KeyPath<Theme.Appearance, ThemeColor>) -> Colour, face: (KeyPath<Theme.TypeSizes, Double>) -> Face
    ) {
        let space = layout.space
        values = [
            "padding": CGFloat(space.padding), "columnGap": CGFloat(space.columnGap), "rowGap": CGFloat(space.rowGap),
            "listRow": CGFloat(space.listRow), "listRowGap": CGFloat(space.listRowGap), "glyph": CGFloat(space.glyph),
            "cell": CGFloat(space.cell), "gridWidth": CGFloat(layout.gridWidth),
            "card": CGFloat(layout.radius.card), "media": CGFloat(layout.radius.media), "inner": max(corner - CGFloat(space.padding), 0),
            "press": CGFloat(layout.motion.press), "pressBounce": CGFloat(layout.motion.pressBounce),
            "secondary": CGFloat(look.secondary), "fill": CGFloat(look.fill), "selected": CGFloat(look.selected), "track": CGFloat(look.track),
            "ink": colour(\.ink), "solid": colour(\.solid), "onSolid": colour(\.onSolid), "accent": colour(\.accent),
            "good": colour(\.good), "warn": colour(\.warn), "bad": colour(\.bad),
            "title": face(\.title), "body": face(\.body), "detail": face(\.detail), "input": face(\.input)
        ]
    }
}
