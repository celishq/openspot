import Foundation

/// The windows that the person works in, such as the playground or an update. While one is open, the app is a regular app
/// in the Dock and in Command-Tab; with none, it is a menu bar app.
public struct WorkWindows: Equatable, Sendable {
    private var count = 0

    public init() {}

    public var isRegular: Bool {
        count > 0
    }

    public mutating func open() {
        count += 1
    }

    public mutating func close() {
        count = max(count - 1, 0)
    }
}
