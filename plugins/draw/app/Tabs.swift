import Foundation

/// The boards open in the window, in the order of their tabs, and the one that shows.
@MainActor
final class Tabs: ObservableObject {
    @Published private(set) var studios: [Studio]
    @Published private(set) var current: Studio

    init(_ studio: Studio) {
        studios = [studio]
        current = studio
    }

    /// The open board with this file.
    func studio(for file: URL) -> Studio? {
        studios.first { $0.file.standardizedFileURL == file.standardizedFileURL }
    }

    /// Shows a board that is open, or opens it in a new tab after the current one.
    func show(_ file: URL) {
        if let open = studio(for: file) {
            current = open
            return
        }
        let studio = Studio(file: file)
        let place = (studios.firstIndex { $0 === current } ?? studios.count - 1) + 1
        studios.insert(studio, at: place)
        current = studio
    }

    /// Closes a tab, and shows its neighbour when it was the current one. Returns false when it was the last tab.
    @discardableResult
    func close(_ studio: Studio) -> Bool {
        guard let index = studios.firstIndex(where: { $0 === studio }) else { return true }
        guard studios.count > 1 else { return false }
        studios.remove(at: index)
        if current === studio { current = studios[min(index, studios.count - 1)] }
        return true
    }
}
