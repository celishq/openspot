import Foundation

public struct Flow: Equatable, Sendable {
    public static let limit = 20

    public private(set) var pages: [FlowSheet] = []
    public private(set) var index = -1

    public init() {}

    public var current: FlowSheet? {
        pages.indices.contains(index) ? pages[index] : nil
    }

    public var behind: FlowSheet? {
        pages.indices.contains(index - 1) ? pages[index - 1] : nil
    }

    public var ahead: FlowSheet? {
        pages.indices.contains(index + 1) ? pages[index + 1] : nil
    }

    public mutating func push(_ page: FlowSheet) {
        guard page != current else { return }
        pages.removeSubrange((index + 1)...)
        pages.removeAll { $0 == page }
        pages.append(page)
        if pages.count > Self.limit { pages.removeFirst(pages.count - Self.limit) }
        index = pages.count - 1
    }

    public mutating func back(steps: Int = 1) -> FlowSheet? {
        guard steps > 0, index - steps >= 0 else { return nil }
        index -= steps
        return pages[index]
    }

    public mutating func forward() -> FlowSheet? {
        guard let page = ahead else { return nil }
        index += 1
        return page
    }

    public mutating func replaceCurrent(with page: FlowSheet) {
        guard current != nil else { return push(page) }
        pages.removeSubrange((index + 1)...)
        pages[index] = page
        if let copy = pages.indices.first(where: { $0 != index && pages[$0] == page }) {
            pages.remove(at: copy)
            index -= 1
        }
    }

    public mutating func clear() {
        pages = []
        index = -1
    }

    public mutating func remove(spot: String) {
        let kept = pages.enumerated().filter { $0.element.spot != spot }
        index = kept.lastIndex { $0.offset <= index } ?? (kept.isEmpty ? -1 : 0)
        pages = kept.map(\.element)
    }
}
