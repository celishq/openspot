import Foundation
import Synchronization

public final class StyleCache: Sendable {
    public static let shared = StyleCache()
    public static let limit = 512

    private let limit: Int
    private let styles = Mutex<[String: Style]>([:])

    public init(limit: Int = StyleCache.limit) {
        self.limit = limit
    }

    public var count: Int {
        styles.withLock { $0.count }
    }

    public func style(of classes: String) -> Style {
        if let kept = styles.withLock({ $0[classes] }) { return kept }
        let style = Style(classes: classes)
        styles.withLock { kept in
            if kept.count >= limit { kept.removeAll() }
            kept[classes] = style
        }
        return style
    }
}
