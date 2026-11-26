import Foundation

public enum ToastFix: Equatable, Sendable {
    case url(URL)
    case settings
    case schedule(String)
}
