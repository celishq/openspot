import Foundation

extension Manifest {
    public struct BoundEvent: Equatable, Sendable {
        public let binding: String
        public let event: String

        init(binding: String, event: String) {
            self.binding = binding
            self.event = event
        }

        init(key: String) {
            binding = String(key.prefix { $0 != "." })
            event = String(key.drop { $0 != "." }.dropFirst())
        }

        public var key: String {
            "\(binding).\(event)"
        }
    }
}
