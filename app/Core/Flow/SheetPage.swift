import Foundation

public struct SheetPage: Equatable, Sendable {
    public let spot: String
    public let route: String?
    public let state: SpotState
    public let list: ItemList
    public let panel: SheetParts?
    public let selection: Int
    public let selectedPart: String?
    public let fieldTitle: String
    public let rect: CGRect
    public let showsField: Bool
    public let top: SheetTop
    public let query: String
    public let recording: String?
    public let keyStatus: String?

    @MainActor
    init(run: SpotRun, rect: CGRect, query: String, recording: String? = nil, keyStatus: String? = nil) {
        spot = run.spot.id
        route = run.route
        state = run.sheetState
        list = run.list
        panel = run.panel
        selection = run.panel?.selectedPart == nil ? run.selection : Int.max
        selectedPart = run.selectedPart?.id
        fieldTitle = run.state.title
        self.rect = rect
        showsField = run.showsField
        top = run.top
        self.query = query
        self.recording = recording
        self.keyStatus = keyStatus
    }
}
