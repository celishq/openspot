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

        public let look: Look
        public let reach: Reach
        public let blur: Double
        public let size: Double
        public let padding: Double

        public init() {
            self.init(look: .blur, reach: .tiles) { _ in nil }
        }

        init(look: Look, reach: Reach, pinned: @escaping (String) -> Double?) {
            self.look = look
            self.reach = reach
            blur = pinned("backdrop-blur") ?? 3
            size = pinned("halo-size") ?? 60
            padding = pinned("halo-padding") ?? 0
        }
    }
}
