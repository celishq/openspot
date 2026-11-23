import Foundation

public struct ContextChip: Equatable, Sendable {
    public let source: String
    public let app: String?
    public let value: ContextValue?

    public init(source: String, app: String?, value: ContextValue? = nil) {
        self.source = source
        self.app = app
        self.value = value
    }

    public var isLoading: Bool {
        value == nil
    }

    func filled(with value: ContextValue) -> ContextChip {
        ContextChip(source: source, app: value.app ?? app, value: value)
    }

    func rank(over front: String?) -> Int {
        let isFront = front != nil && app == front
        let isText = value?.kind == .text
        return (isFront ? 0 : 2) + (isText ? 0 : 1)
    }
}
