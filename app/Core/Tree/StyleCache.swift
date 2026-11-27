import Foundation
import Synchronization

public final class StyleCache: Sendable {
    public final class Kept: Equatable, Sendable {
        public let style: Style

        init(_ style: Style) {
            self.style = style
        }

        public static func == (left: Kept, right: Kept) -> Bool {
            left === right || left.style == right.style
        }
    }

    public static let shared = StyleCache()
    public static let limit = 512

    private let limit: Int
    private let styles = Mutex<[String: Style]>([:])
    private let kept = Mutex<[String: Kept]>([:])

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

    func kept(_ style: Style, classes: String?, grows: Bool?) -> Kept {
        let key = "\(grows.map { $0 ? "1" : "0" } ?? "-")\(classes.map { "+" + $0 } ?? "")"
        if let kept = kept.withLock({ $0[key] }) { return kept }
        let made = Kept(style)
        kept.withLock { kept in
            if kept.count >= limit { kept.removeAll() }
            kept[key] = made
        }
        return made
    }
}
