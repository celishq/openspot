import Foundation

public struct AttachmentChip: Equatable, Sendable {
    public enum Look: Hashable, Sendable {
        case file(FileIcon)
        case symbol(String)
    }

    public enum State: Equatable, Sendable {
        case unread
        case loading
        case ready(AttachmentValue)
        case empty(String)
        case failed(String)
        case denied(String)
    }

    static let loadingSymbol = "ellipsis"

    public let source: String
    public let app: String?
    public let appName: String?
    public let look: Look
    public internal(set) var state: State
    public internal(set) var showsKind = false

    public init(source: String, app: String?, appName: String? = nil, look: Look, state: State = .loading) {
        self.source = source
        self.app = app
        self.appName = appName
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

    var isRead: Bool {
        switch state {
        case .unread, .failed, .denied: false
        case .loading, .ready, .empty: true
        }
    }

    func rank(over front: String?) -> Int {
        let isFront = front != nil && app == front
        let isText = value?.kind == .text
        return (isFront ? 0 : 2) + (isText ? 0 : 1)
    }
}
