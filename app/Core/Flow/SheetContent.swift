import Foundation

public struct SheetContent {
    public let panel: SheetParts?
    public let list: ItemList
    public let state: SpotState
    public let form: FormDraft?
    public let recording: String?
    public let keys: KeyRecording
    public let isHeld: Bool
    public let takesFiles: Bool
    public let selection: () -> Int
    public let selectedPart: () -> String?
    public let nudge: () -> SheetParts.Nudge
    public let menuOpening: () -> SheetParts.MenuOpening?
    public let work: (SpotPart) -> ScriptCall?
    public let create: () -> CommandAction?

    @MainActor
    public init(page: SheetPage) {
        panel = page.panel
        list = page.list
        state = page.state
        form = nil
        recording = page.recording
        keys = KeyRecording(status: page.keyStatus)
        isHeld = true
        takesFiles = false
        selection = { page.selection }
        selectedPart = { page.selectedPart }
        nudge = { .rest }
        menuOpening = { nil }
        work = { _ in nil }
        create = { nil }
    }

    init(
        panel: SheetParts?, list: ItemList, state: SpotState, form: FormDraft?, recording: String?, keys: KeyRecording,
        selection: @escaping () -> Int, selectedPart: @escaping () -> String?, nudge: @escaping () -> SheetParts.Nudge,
        menuOpening: @escaping () -> SheetParts.MenuOpening?, work: @escaping (SpotPart) -> ScriptCall?, create: @escaping () -> CommandAction?
    ) {
        self.panel = panel
        self.list = list
        self.state = state
        self.form = form
        self.recording = recording
        self.keys = keys
        isHeld = false
        takesFiles = list.hasFiles
        self.selection = selection
        self.selectedPart = selectedPart
        self.nudge = nudge
        self.menuOpening = menuOpening
        self.work = work
        self.create = create
    }
}
