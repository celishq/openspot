import Foundation

extension Theme {
    public struct Layout: Equatable, Sendable {
        public let space: Space
        public let radius: Radius
        public let type: TypeSizes
        public let motion: Motion
        public let backdrop: Backdrop
        public let gridWidth: Double
        public let panelWidth: Double
        public let panelHeight: Double
        public let hintBlock: Double
        public let sheetMaxHeight: Double
        public let sheetFieldDrop: Double
        public let sheetRowsTop: Double
        public let gridTop: Double
        public let partsWidth: Double
        public let backdropEdges: [BackdropEdge]

        static let exactKinds: [(String, ThemeKind)] = [
            "cell", "column-gap", "row-gap", "padding", "glyph", "list-row", "list-row-gap", "menu-row", "menu-padding",
            "window-corner", "media-corner", "mark-corner", "title", "body", "detail", "input"
        ].map { ($0, ThemeKind.points()) } + ["grow", "shrink", "move", "fade-in", "fade-out", "press", "settle"].map { ($0, ThemeKind.seconds) }
            + [("press-bounce", .strength), ("pressed-scale", .scale), ("lifted-scale", .scale), ("focused-scale", .scale)]
            + [("backdrop-blur", .points()), ("halo-size", .points(Double(SpotTokens.backdropLeastFade)...Double(SpotTokens.halo), example: 60))]
            + [("halo-padding", .points(0...Double(SpotTokens.halo - SpotTokens.backdropLeastFade), example: 10))]

        public init() {
            self.init(choices: ThemeValues(), exact: ThemeValues())
        }

        init(choices: ThemeValues, exact values: ThemeValues) {
            let exact = { (key: String) in values.number("advanced", key) }
            space = Space(density: choices.number("look", "density") ?? 1, exact: exact)
            radius = Radius(corner: choices.number("look", "corner") ?? Radius.openspotCorner, exact: exact)
            type = TypeSizes(base: choices.number("look", "type") ?? TypeSizes.openspotBody, exact: exact)
            motion = Motion(speed: choices.number("look", "speed") ?? 1, exact: exact)
            backdrop = Backdrop(style: choices.word("look", "backdrop") ?? .blur, reach: choices.word("look", "reach") ?? .tiles, exact: exact)
            let columns = Double(SpotTokens.columns)
            let halo = Double(SpotTokens.halo)
            gridWidth = columns * space.cell + (columns - 1) * space.columnGap
            panelWidth = gridWidth + 2 * halo
            hintBlock = space.rowGap + Double(SpotTokens.hintPillHeight)
            panelHeight = 2 * halo + 7 * space.cell + 6 * space.rowGap + hintBlock
            sheetMaxHeight = panelHeight - 2 * halo - hintBlock
            sheetFieldDrop = space.padding + space.glyph + space.rowGap
            sheetRowsTop = sheetFieldDrop + space.listRow + space.rowGap
            gridTop = halo + space.cell + space.rowGap
            partsWidth = gridWidth - 2 * space.padding
            backdropEdges = BackdropEdge.edges(of: backdrop)
        }
    }

    public struct Space: Equatable, Sendable {
        public let cell: Double
        public let columnGap: Double
        public let rowGap: Double
        public let padding: Double
        public let glyph: Double
        public let listRow: Double
        public let listRowGap: Double
        public let menuRow: Double
        public let menuPadding: Double

        init(density: Double, exact: @escaping (String) -> Double?) {
            let gap = { (key: String, base: Double) in exact(key) ?? (base * density).rounded() }
            cell = exact("cell") ?? 64
            columnGap = gap("column-gap", 11)
            rowGap = gap("row-gap", 12)
            padding = gap("padding", 13)
            glyph = exact("glyph") ?? 36
            listRow = exact("list-row") ?? 40
            listRowGap = gap("list-row-gap", 6)
            menuRow = exact("menu-row") ?? 32
            menuPadding = gap("menu-padding", 8)
        }
    }

    public struct Radius: Equatable, Sendable {
        static let openspotCorner = 26.0

        public let card: Double
        public let window: Double
        public let media: Double
        public let cornerMark: Double

        init(corner: Double, exact: @escaping (String) -> Double?) {
            card = corner
            window = exact("window-corner") ?? corner * 16 / Self.openspotCorner
            media = exact("media-corner") ?? corner * 8 / Self.openspotCorner
            cornerMark = exact("mark-corner") ?? corner * 6 / Self.openspotCorner
        }
    }

    public struct TypeSizes: Equatable, Sendable {
        static let openspotBody = 13.0

        public let title: Double
        public let body: Double
        public let detail: Double
        public let input: Double

        public init() {
            self.init(base: Self.openspotBody) { _ in nil }
        }

        init(base: Double, exact: @escaping (String) -> Double?) {
            title = exact("title") ?? base
            body = exact("body") ?? base
            detail = exact("detail") ?? base - 2
            input = exact("input") ?? base + 1
        }
    }

    public struct Motion: Equatable, Sendable {
        public let grow: Double
        public let shrink: Double
        public let move: Double
        public let fadeIn: Double
        public let fadeOut: Double
        public let press: Double
        public let settle: Double
        public let pressBounce: Double
        public let pressedScale: Double
        public let liftedScale: Double
        public let focusedScale: Double

        public init() {
            self.init(speed: 1) { _ in nil }
        }

        init(speed: Double, exact: @escaping (String) -> Double?) {
            let time = { (key: String, base: Double) in exact(key) ?? base / speed }
            grow = time("grow", 0.15)
            shrink = time("shrink", 0.2)
            move = time("move", 0.25)
            fadeIn = time("fade-in", 0.1)
            fadeOut = time("fade-out", 0.12)
            press = time("press", 0.2)
            settle = time("settle", 0.25)
            pressBounce = exact("press-bounce") ?? 0.2
            pressedScale = exact("pressed-scale") ?? 1.04
            liftedScale = exact("lifted-scale") ?? 1.05
            focusedScale = exact("focused-scale") ?? 1.04
        }
    }
}
