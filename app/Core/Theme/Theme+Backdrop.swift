import Foundation

extension Theme {
    public struct Backdrop: Equatable, Sendable {
        public enum Look: String, Equatable, Sendable {
            case blur
            case tint
        }

        public enum Reach: String, Equatable, Sendable {
            case tiles
            case screen
        }

        public fileprivate(set) var look = Look.blur
        public fileprivate(set) var reach = Reach.tiles
        public fileprivate(set) var blur = 3.0
        public fileprivate(set) var size = 60.0
        public fileprivate(set) var padding = 0.0

        public init() {}

        static var fields: [String: ThemeField<Backdrop>] {
            [
                "look": .word(.backdropLook, \.look), "reach": .word(.backdropReach, \.reach), "blur": .number(.points, \.blur),
                "size": .number(.haloSize, \.size), "padding": .number(.haloPadding, \.padding)
            ]
        }
    }
}
