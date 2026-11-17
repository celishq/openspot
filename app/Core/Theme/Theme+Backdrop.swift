import Foundation

extension Theme {
    public struct Backdrop: Equatable, Sendable {
        public enum Style: String, CaseIterable, Equatable, Sendable {
            case blur
            case tint
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

        public init() {
            self.init(style: .blur, reach: .tiles) { _ in nil }
        }

        init(style: Style, reach: Reach, exact: @escaping (String) -> Double?) {
            self.style = style
            self.reach = reach
            blur = exact("backdrop-blur") ?? 3
            size = exact("halo-size") ?? 60
            padding = exact("halo-padding") ?? 0
        }
    }
}
