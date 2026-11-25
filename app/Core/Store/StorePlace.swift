import Foundation

public enum StorePlace: Hashable, Sendable {
    case mine
    case source(StoreSource)

    public var source: StoreSource? {
        if case .source(let source) = self { source } else { nil }
    }
}
