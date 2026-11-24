import Foundation

public struct AttachmentChip: Equatable, Sendable {
    public enum Look: Hashable, Sendable {
        case file(FileIcon)
        case symbol(String)
    }

    public enum State: Equatable, Sendable {
        case loading
        case ready(AttachmentValue)
    }

    static let loadingSymbol = "ellipsis"

    public let source: String
    public let app: String?
    public let look: Look
    public let state: State
    public internal(set) var showsKind = false

    public init(source: String, app: String?, look: Look, state: State = .loading) {
        self.source = source
        self.app = app
        self.look = look
        self.state = state
    }

    public var value: AttachmentValue? {
        guard case .ready(let value) = state else { return nil }
        return value
    }

    public var isLoading: Bool {
        state == .loading
    }

    func rank(over front: String?) -> Int {
        let isFront = front != nil && app == front
        let isText = value?.kind == .text
        return (isFront ? 0 : 2) + (isText ? 0 : 1)
    }
}
