import Foundation

extension Theme {
    public struct Backdrop: Equatable, Sendable {
        public enum Style: String, CaseIterable, Equatable, Sendable {
            case blur
            case tint
            case veil
        }

        public enum Reach: String, CaseIterable, Equatable, Sendable {
            case tiles
            case screen
        }

        public let style: Style
        public let reach: Reach
        public let blur: Double
        public let size: Double
        public let padding: Double
        public let shadow: Double

        public init() {
            self.init(style: .blur, reach: .tiles) { _ in nil }
        }

        init(style: Style, reach: Reach, exact: @escaping (String) -> Double?) {
            self.style = style
            self.reach = reach
            blur = exact("backdrop-blur") ?? 1
            size = exact("halo-size") ?? 30
            padding = exact("halo-padding") ?? 0
            shadow = exact("card-shadow-size") ?? 24
        }
    }
}
