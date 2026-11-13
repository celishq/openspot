import Foundation

/// The tabs of the window, in order, and the one that shows. A tab shows a board, or the start page as a New Tab, as a
/// browser does. The window always has a tab, so the last one to close becomes a New Tab.
@MainActor
final class Tabs: ObservableObject {
    /// One tab: its board, or none for a New Tab.
    struct Page: Identifiable {
        let id = UUID()
        var studio: Studio?
    }

    @Published private(set) var pages: [Page]
    @Published private(set) var currentID: UUID

    init(_ studio: Studio) {
        let page = Page(studio: studio)
        pages = [page]
        currentID = page.id
    }

    /// The board that shows, or nil on a New Tab.
    var studio: Studio? {
        pages.first { $0.id == currentID }?.studio
    }

    var studios: [Studio] {
        pages.compactMap(\.studio)
    }

    /// Whether the start page shows.
    var home: Bool {
        studio == nil
    }

    /// The open board with this file.
    func studio(for file: URL) -> Studio? {
        studios.first { $0.file.standardizedFileURL == file.standardizedFileURL }
    }

    /// Whether this board shows now.
    func shows(_ file: URL) -> Bool {
        studio?.file.standardizedFileURL == file.standardizedFileURL
    }

    func select(_ id: UUID) {
        currentID = id
    }

    /// Shows a board in its tab. A board that is not open takes the New Tab that shows, or a new tab after this one.
    func show(_ file: URL) {
        if let page = pages.first(where: { $0.studio?.file.standardizedFileURL == file.standardizedFileURL }) {
            currentID = page.id
            return
        }
        let studio = Studio(file: file)
        if let index = pages.firstIndex(where: { $0.id == currentID }), pages[index].studio == nil {
            pages[index].studio = studio
        } else {
            insert(Page(studio: studio))
        }
    }

    /// Adds a New Tab after this one and shows it.
    func openStart() {
        insert(Page())
    }

    /// Closes a tab and shows its neighbour. The last tab becomes a New Tab.
    func close(_ id: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages.remove(at: index)
        if pages.isEmpty {
            let page = Page()
            pages = [page]
            currentID = page.id
        } else if currentID == id {
            currentID = pages[min(index, pages.count - 1)].id
        }
    }

    /// Shows a board from its new place in the tab that showed it from the old one.
    func replace(_ id: UUID, with file: URL) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages[index].studio = Studio(file: file)
    }

    /// The tab of a board.
    func page(of studio: Studio) -> UUID? {
        pages.first { $0.studio === studio }?.id
    }

    private func insert(_ page: Page) {
        let place = pages.firstIndex { $0.id == currentID }.map { $0 + 1 } ?? pages.count
        pages.insert(page, at: place)
        currentID = page.id
    }
}
