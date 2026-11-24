import Foundation

public enum ClipboardContents: Equatable, Sendable {
    case none
    case text
    case files([URL])
    case image(String)
}
