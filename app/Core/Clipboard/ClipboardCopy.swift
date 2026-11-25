import Foundation

public struct ClipboardCopy: Equatable, Sendable {
    let count: Int
    let image: URL?
    var thumbnail: URL?
}
