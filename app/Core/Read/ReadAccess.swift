import Foundation

public enum ReadAccess: String, Sendable {
    case allowed, denied, unasked, unknown
}
