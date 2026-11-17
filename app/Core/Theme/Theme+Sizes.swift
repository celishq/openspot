import Foundation

extension Theme {
    public struct Layout: Equatable, Sendable {
        public fileprivate(set) var space = Space()
        public fileprivate(set) var radius = Radius()
        public fileprivate(set) var type = TypeSizes()
        public fileprivate(set) var motion = Motion()
        public fileprivate(set) var backdrop = Backdrop()

        public init() {}

        static var fields: [ThemeKey: ThemeField<Layout>] {
            [
                named("space", \.space, Space.fields), named("radius", \.radius, Radius.fields), named("type", \.type, TypeSizes.fields),
                named("motion", \.motion, Motion.fields), named("backdrop", \.backdrop, Backdrop.fields)
            ]
                .reduce(into: [:]) { all, part in all.merge(part) { one, _ in one } }
        }
    }

    public struct Space: Equatable, Sendable {
        public fileprivate(set) var cell = 64.0
        public fileprivate(set) var columnGap = 11.0
        public fileprivate(set) var rowGap = 12.0
        public fileprivate(set) var padding = 13.0
        public fileprivate(set) var glyph = 36.0
        public fileprivate(set) var listRow = 40.0
        public fileprivate(set) var listRowGap = 6.0
        public fileprivate(set) var menuRow = 32.0
        public fileprivate(set) var menuPadding = 8.0

        public init() {}

        static var fields: [String: ThemeField<Space>] {
            [
                "cell": .number(.points, \.cell), "column-gap": .number(.points, \.columnGap), "row-gap": .number(.points, \.rowGap),
                "padding": .number(.points, \.padding), "glyph": .number(.points, \.glyph), "list-row": .number(.points, \.listRow),
                "list-row-gap": .number(.points, \.listRowGap), "menu-row": .number(.points, \.menuRow), "menu-padding": .number(.points, \.menuPadding)
            ]
        }
    }

    public struct Radius: Equatable, Sendable {
        public fileprivate(set) var card = 26.0
        public fileprivate(set) var window = 16.0
        public fileprivate(set) var media = 8.0
        public fileprivate(set) var cornerMark = 6.0

        public init() {}

        static var fields: [String: ThemeField<Radius>] {
            ["card": .number(.points, \.card), "window": .number(.points, \.window), "media": .number(.points, \.media), "corner-mark": .number(.points, \.cornerMark)]
        }
    }

    public struct TypeSizes: Equatable, Sendable {
        public fileprivate(set) var title = 13.0
        public fileprivate(set) var body = 13.0
        public fileprivate(set) var detail = 11.0
        public fileprivate(set) var input = 14.0

        public init() {}

        static var fields: [String: ThemeField<TypeSizes>] {
            ["title": .number(.points, \.title), "body": .number(.points, \.body), "detail": .number(.points, \.detail), "input": .number(.points, \.input)]
        }
    }

    public struct Motion: Equatable, Sendable {
        public fileprivate(set) var grow = 0.15
        public fileprivate(set) var shrink = 0.2
        public fileprivate(set) var move = 0.25
        public fileprivate(set) var fadeIn = 0.1
        public fileprivate(set) var fadeOut = 0.12
        public fileprivate(set) var press = 0.2
        public fileprivate(set) var settle = 0.25
        public fileprivate(set) var pressBounce = 0.2
        public fileprivate(set) var pressedScale = 1.04
        public fileprivate(set) var liftedScale = 1.05
        public fileprivate(set) var focusedScale = 1.04

        public init() {}

        static var fields: [String: ThemeField<Motion>] {
            [
                "grow": .number(.seconds, \.grow), "shrink": .number(.seconds, \.shrink), "move": .number(.seconds, \.move),
                "fade-in": .number(.seconds, \.fadeIn), "fade-out": .number(.seconds, \.fadeOut), "press": .number(.seconds, \.press),
                "settle": .number(.seconds, \.settle), "press-bounce": .number(.strength, \.pressBounce),
                "pressed-scale": .number(.scale, \.pressedScale), "lifted-scale": .number(.scale, \.liftedScale), "focused-scale": .number(.scale, \.focusedScale)
            ]
        }
    }
}
