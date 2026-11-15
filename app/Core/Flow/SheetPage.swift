import Foundation

public struct SheetPage: Equatable, Sendable {
    public let spot: String
    public let page: String?
    public let state: SpotState
    public let list: ItemList
    public let panel: SheetParts?
    public let selection: Int
    public let rect: CGRect
    public let showsField: Bool
    public let query: String

    @MainActor
    init(run: SpotRun, rect: CGRect, query: String) {
        spot = run.spot.id
        page = run.page
        state = run.shownState
        list = run.list
        panel = run.panel
        selection = run.selection
        self.rect = rect
        showsField = run.showsField
        self.query = query
    }
}
