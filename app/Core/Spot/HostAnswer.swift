import Foundation

struct HostAnswer: Equatable, Sendable {
    let frame: String
    var effects: [SpotEffect] = []
}
