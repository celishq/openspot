import Foundation
import Observation

@MainActor
@Observable
public final class SpotRun {
    public enum Report: Sendable {
        case toast(ToastNote)
        case dropToast(String)
        case frame(String)
        case parts
        case listChange
        case answered
        case landed
        case closed
        case move(FlowMove)
        case refused(String?)
        case done
        case form(ItemForm)
        case attachment(AttachmentValue)
        case attachmentFailed(String)
    }

    public enum ShowNeed: Sendable {
        case moment
        case clock
        case change
    }

    enum Ask {
        case show(generation: Int?, reports: Bool, query: String = "", tells: Bool = true)
        case search(String)
        case answer(String)
        case more(after: String, query: String)

        var isAnswer: Bool {
            if case .answer = self { return true }
            return false
        }
    }

    struct Act {
        var generation: Int?
        var keeping: String?
        var showsAfter = true
        var undo: SpotState?
        var ended: ((ScriptCall.End) -> Void)?
        var first: FirstFrame?
        var started: Date?
        var closes = false
        var tells = true
    }

    enum Purpose {
        case ask(Ask)
        case act(Act)
        case form(CheckedContinuation<Frame?, Error>)
    }

    struct Call {
        var message: Message
        let key: String
        var limit: TimeInterval?
        var event: ShowEvent?
        var purpose: Purpose
        var chain: [String] = []
        var isPressed = true

        var handler: String {
            message.handler
        }

        var isByPerson: Bool {
            if case .ask = purpose { return false }
            return isPressed
        }
    }

    static let answerAge: TimeInterval = 5
    static let textPause: Duration = .milliseconds(300)
    static let sliderPause: Duration = .milliseconds(100)
    static let buildPause: Duration = .milliseconds(500)
    static let pressPause: TimeInterval = 1
    static let actPause: TimeInterval = 1
    static let waitingLimit = 8
    static let showKey = "show"
    static let searchKey = "search"
    static let moreKey = "more"
    static let answerKey = "answer"
    static let cardKey = "card"
    static let levelKey = "level"
    static let globalKey = "global"
    static let buildKey = "build"

    public internal(set) var spot: Spot {
        didSet { runs.showMarks(of: spot.id) }
    }
    public internal(set) var answers: [SpotItem] = []
    var answerQuery = ""
    var answeredQuery = ""
    var answerWaiters: [() -> Void] = []

    public var isAnswering: Bool {
        answeredQuery != answerQuery
    }
    @ObservationIgnored var rows: ItemList

    public var list: ItemList {
        get {
            access(keyPath: \.list)
            return rows
        }
        set {
            guard newValue != rows else { return }
            let tellsList = !newValue.differsOnlyInText(from: rows)
            let findsSameRows = newValue.findsSameRows(as: rows)
            tell(\.query, newValue.query != rows.query) {
                tell(\.selection, newValue.selected != rows.selected) {
                    tell(\.list, tellsList) { rows = newValue }
                }
            }
            guard tellsList else { return }
            settle()
            if !findsSameRows { onReport(.listChange) }
        }
    }

    public var query: String {
        access(keyPath: \.query)
        return rows.query
    }

    private func tell<Member>(_ path: KeyPath<SpotRun, Member>, _ tells: Bool, _ change: () -> Void) {
        tells ? withMutation(keyPath: path, change) : change()
    }

    public var selection: Int {
        access(keyPath: \.selection)
        return rows.selected
    }

    public var selectedItem: SpotItem? {
        access(keyPath: \.list)
        access(keyPath: \.selection)
        return rows.selectedItem
    }
    @ObservationIgnored private var parts: SheetParts?
    public internal(set) var panel: SheetParts? {
        get {
            access(keyPath: \.panel)
            return parts
        }
        set {
            guard newValue != parts else { return }
            if let newValue, let parts, newValue.differsOnlyInSelection(from: parts) {
                withMutation(keyPath: \.selectedPart) { self.parts = newValue }
                return
            }
            if let newValue, let parts, let changed = newValue.changedParts(from: parts) {
                self.parts = newValue
                changed.forEach { withMutation(keyPath: \.[part: $0]) {} }
                return
            }
            withMutation(keyPath: \.panel) { parts = newValue }
            settle()
        }
    }
    public subscript(part id: String) -> SpotPart? {
        access(keyPath: \.[part: id])
        return parts?.tree.node(id)?.part
    }
    public subscript(cardPart id: String) -> SpotPart? {
        access(keyPath: \.[cardPart: id])
        return keptState.face.node(id)?.part
    }
    public var selectedPart: SpotPart? {
        access(keyPath: \.panel)
        access(keyPath: \.selectedPart)
        return parts?.selectedPart
    }
    public internal(set) var nudge = SheetParts.Nudge.rest
    public internal(set) var menuOpening: SheetParts.MenuOpening?
    public var isOpen: Bool {
        runs.openID == spot.id
    }
    public var isFloating: Bool {
        runs.floating.contains(spot.id)
    }
    public var places: Set<SheetPlace> {
        Set([isOpen ? SheetPlace.panel : nil, isFloating ? .float : nil].compactMap { $0 })
    }
    var showsSheet: Bool {
        !places.isEmpty
    }
    public private(set) var shape = Shape(rows: 0, perLine: 1)
    public private(set) var isWaiting = false
    public private(set) var partsRect: CGRect?
    public private(set) var takesKeys = true
    public private(set) var sheetRect = SpotTokens.sheetRect(rows: 0)
    public private(set) var showsField = true
    public private(set) var top = SheetTop.plain
    @ObservationIgnored var heardRows: Bool? {
        didSet { settle() }
    }
    @ObservationIgnored private var keptState: SpotState
    public internal(set) var state: SpotState {
        get {
            access(keyPath: \.state)
            return keptState
        }
        set {
            let old = keptState
            guard newValue != old else { return }
            if let changed = newValue.changedParts(from: old) {
                keptState = newValue
                changed.forEach { withMutation(keyPath: \.[cardPart: $0]) {} }
            } else {
                withMutation(keyPath: \.state) { keptState = newValue }
            }
            if (newValue.active == true) != isOn { isOn = newValue.active == true }
            if newValue.subtitle != old.subtitle { settle() }
            onReport(.listChange)
        }
    }
    public private(set) var isOn = false
    public internal(set) var reading: MetricReading {
        didSet { runs.showMarks(of: spot.id) }
    }
    public internal(set) var failure: String?
    public internal(set) var failedItem: String?
    @ObservationIgnored public internal(set) var calls: [ScriptCall] = []
    @ObservationIgnored public internal(set) var partsAnswers = 0
    @ObservationIgnored var actCalls: [ScriptCall] = []
    @ObservationIgnored var isHeld = false
    @ObservationIgnored var heldRoute: String?
    public internal(set) var acts: [ScriptCall] = [] {
        didSet { if acts.first?.detail != oldValue.first?.detail { settle() } }
    }
    @ObservationIgnored public var onReport: (Report) -> Void = { _ in }
    @ObservationIgnored public var partsArrival: (_ movesLayout: Bool, _ bring: () -> Void) -> Void = { $1() }
    @ObservationIgnored let runs: SpotRuns
    @ObservationIgnored let prepare: ([SpotItem], [String]) async -> Void
    @ObservationIgnored var glyphs: (rows: [SpotItem], glyphs: [String]) = ([], [])
    @ObservationIgnored var link: ScriptMode
    @ObservationIgnored var answered: Date? {
        didSet { settle() }
    }
    @ObservationIgnored var lastAnswer: Frame?
    @ObservationIgnored var isParked = false
    @ObservationIgnored var shownFrame: String?
    @ObservationIgnored var shownEvent: ShowEvent?
    @ObservationIgnored var finishesShow = false
    @ObservationIgnored var isShowCut = false
    @ObservationIgnored var hasAsked = false
    @ObservationIgnored var waiter: (() -> Void)?
    @ObservationIgnored var selecting: String?
    @ObservationIgnored var showsAgain = false
    @ObservationIgnored var sheetAgain = false
    @ObservationIgnored var eventAgain: ShowEvent?
    @ObservationIgnored var pauses: [String: Task<Void, Never>] = [:]
    @ObservationIgnored var editing: String?
    @ObservationIgnored var typed: String?
    @ObservationIgnored var waitingFiles: [Message] = []
    @ObservationIgnored var waitingKeys: [String] = []
    @ObservationIgnored var clockShown: Date?
    public internal(set) var page: FlowSheet

    public var route: String? {
        page.route
    }
    @ObservationIgnored var pageStates: [(route: String?, state: PageState)] = []

    init(spot: Spot, runs: SpotRuns, recent: [String], prepare: @escaping ([SpotItem], [String]) async -> Void) {
        self.spot = spot
        page = FlowSheet(spot: spot.id)
        self.runs = runs
        self.prepare = prepare
        link = Self.link(for: spot, runs: runs)
        rows = ItemList(recent: recent)
        keptState = spot.headerState
        reading = MetricReading(label: spot.name, headerSymbol: spot.headerSymbol)
        isOn = spot.headerState.active == true
        settle()
        link.run = self
    }

    nonisolated deinit {}

    private static func link(for spot: Spot, runs: SpotRuns) -> ScriptMode {
        runs.standIn?(spot) ?? runs.mode(of: spot).init(runs: runs)
    }

    var script: any ScriptMode.Type {
        runs.mode(of: spot)
    }

    public func update(_ new: Spot) {
        let header = spot.headerState
        if new.triggers.search != spot.triggers.search { answer("") }
        let next = runs.mode(of: new)
        if next.keepsState != script.keepsState || (next == InlineMode.self) != (script == InlineMode.self) {
            let old = link
            link = Self.link(for: new, runs: runs)
            link.run = self
            old.end()
        }
        shownFrame = nil
        spot = lastAnswer.map(new.taking) ?? new
        if reading.label != new.name || reading.headerSymbol != new.headerSymbol {
            reading = MetricReading(label: new.name, headerSymbol: new.headerSymbol)
        }
        if new.headerState != header { takeState(lastAnswer) }
    }

    public var awaitsAnswer: Bool {
        spot.showsState && !hasAsked
    }

    public struct Shape: Equatable, Sendable {
        public let rows: Int
        public let perLine: Int
        public let setsApart: Bool
        public let sections: Int

        public init(rows: Int, perLine: Int, setsApart: Bool = false, sections: Int = 0) {
            self.rows = rows
            self.sections = sections
            self.perLine = perLine
            self.setsApart = setsApart
        }
    }

    func layOut() {
        if var next = parts {
            next.place(top: top)
            if next != panel { panel = next }
        }
        settle()
    }

    func settle() {
        let next = Shape(rows: rows.lineCount, perLine: rows.perLine, setsApart: rows.setsApart, sections: rows.sectionCount)
        if next != shape { shape = next }
        let waits = heardRows == nil && showsSheet && answered == nil && panel?.holdsParts != true && rows.search == .local && rows.isLoading && !rows.holdsItems
        if waits != isWaiting { isWaiting = waits }
        let showsRows = heardRows ?? (!waits && panel?.showsRows != false)
        let field = showsRows && rows.search != .off && panel?.placesSearch != true
        if field != showsField { showsField = field }
        let header = SheetHeader.shared.extra(for: shownState.subtitle)
        let nextTop = SheetTop(showsRows: panel.map { $0.showsRows && !$0.placesSearch } ?? true, search: rows.search, header: header)
        if nextTop != top { top = nextTop }
        if var placed = panel, placed.top != nextTop {
            placed.place(top: nextTop)
            panel = placed
        }
        let rect = panel.flatMap { $0.holdsParts ? SpotTokens.panelRect($0) : nil }
        if rect != partsRect { partsRect = rect }
        let keys = panel?.showsRows != false
        if keys != takesKeys { takesKeys = keys }
        let sheet = rect ?? SpotTokens.sheetRect(rows: next.rows, perLine: next.perLine, setsApart: next.setsApart, sections: next.sections, top: nextTop)
        if sheet != sheetRect { sheetRect = sheet }
    }

    func hear(_ lines: Frame?) {
        guard let lines else {
            heardRows = nil
            return
        }
        guard isWaiting else { return }
        heardRows = lines.showsRows
    }
}
