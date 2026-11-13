import Foundation

/// The boards open in the window, in the order of their tabs, and the one that shows. With no tab open, the window shows
/// the start page of all boards, and `current` keeps the last board that showed.
@MainActor
final class Tabs: ObservableObject {
    @Published private(set) var studios: [Studio]
    @Published private(set) var current: Studio
    @Published private(set) var home = false

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
        home = false
        if let open = studio(for: file) {
            current = open
            return
        }
        let studio = Studio(file: file)
        let place = studios.firstIndex { $0 === current }.map { $0 + 1 } ?? studios.count
        studios.insert(studio, at: place)
        current = studio
    }

    /// Closes a tab, and shows its neighbour when it was the current one, or the start page after the last tab.
    func close(_ studio: Studio) {
        guard let index = studios.firstIndex(where: { $0 === studio }) else { return }
        studios.remove(at: index)
        if studios.isEmpty {
            home = true
        } else if current === studio {
            current = studios[min(index, studios.count - 1)]
        }
    }

    /// Whether this board shows now.
    func shows(_ file: URL) -> Bool {
        !home && current.file.standardizedFileURL == file.standardizedFileURL
    }
}
