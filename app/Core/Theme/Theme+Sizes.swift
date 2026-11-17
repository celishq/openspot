import Foundation

extension Theme {
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

        static var points: [String: WritableKeyPath<Space, Double>] {
            [
                "cell": \.cell, "column-gap": \.columnGap, "row-gap": \.rowGap, "padding": \.padding, "glyph": \.glyph,
                "list-row": \.listRow, "list-row-gap": \.listRowGap, "menu-row": \.menuRow, "menu-padding": \.menuPadding
            ]
        }
    }

    public struct Radius: Equatable, Sendable {
        public fileprivate(set) var card = 26.0
        public fileprivate(set) var window = 16.0
        public fileprivate(set) var media = 8.0
        public fileprivate(set) var cornerMark = 6.0

        public init() {}

        static var points: [String: WritableKeyPath<Radius, Double>] {
            ["card": \.card, "window": \.window, "media": \.media, "corner-mark": \.cornerMark]
        }
    }

    public struct TypeSizes: Equatable, Sendable {
        public fileprivate(set) var title = 13.0
        public fileprivate(set) var body = 13.0
        public fileprivate(set) var detail = 11.0
        public fileprivate(set) var input = 14.0

        public init() {}

        static var points: [String: WritableKeyPath<TypeSizes, Double>] {
            ["title": \.title, "body": \.body, "detail": \.detail, "input": \.input]
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

        static var seconds: [String: WritableKeyPath<Motion, Double>] {
            [
                "grow": \.grow, "shrink": \.shrink, "move": \.move, "fade-in": \.fadeIn, "fade-out": \.fadeOut,
                "press": \.press, "settle": \.settle
            ]
        }

        static var strengths: [String: WritableKeyPath<Motion, Double>] {
            ["press-bounce": \.pressBounce]
        }

        static var scales: [String: WritableKeyPath<Motion, Double>] {
            ["pressed-scale": \.pressedScale, "lifted-scale": \.liftedScale, "focused-scale": \.focusedScale]
        }
    }
}
