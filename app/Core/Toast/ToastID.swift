import Foundation

public struct ToastID: Hashable, Sendable {
    public enum Name: Hashable, Sendable {
        case given(String)
        case made(Int)
    }

    public let spot: String
    public let name: Name
}
