import Foundation
import Observation

@MainActor
@Observable
public final class SpotRun {
    public enum Report: Sendable {
        case toast(String)
        case failure(String)
        case failureWithFix(String, URL)
        case frame(String)
        case parts
        case listChange
        case landed
        case closed
        case move(FlowMove)
        case refused(String?)
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
        var ended: (() -> Void)?
        var first: FirstFrame?
        var started: Date?
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

        var action: SpotAction {
            message.action
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

    @ObservationIgnored var finding: Task<Void, Never>?

    public func landRows() {
        guard rows.isFinding else { return }
        finding?.cancel()
        list.landFinding()
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
            withMutation(keyPath: \.panel) { parts = newValue }
            settle()
        }
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
    public private(set) var kind = SheetKind.rows
    public private(set) var partsRect: CGRect?
    public private(set) var partsKind: SheetKind?
    public private(set) var sheetRect = SpotTokens.sheetRect(rows: 0)
    public private(set) var showsField = true
    public private(set) var top = SheetTop.plain
    @ObservationIgnored var heardKind: SheetKind? {
        didSet { settle() }
    }
    public internal(set) var state: SpotState {
        didSet {
            guard state != oldValue else { return }
            if (state.on == true) != isOn { isOn = state.on == true }
            if state.subtitle != oldValue.subtitle { settle() }
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
    public internal(set) var acts: [ScriptCall] = [] {
        didSet { if acts.first?.detail != oldValue.first?.detail { settle() } }
    }
    @ObservationIgnored public var onReport: (Report) -> Void = { _ in }
    @ObservationIgnored public var partsArrival: (() -> Void) -> Void = { $0() }
    @ObservationIgnored let runs: SpotRuns
    @ObservationIgnored let prepare: ([SpotItem], [String]) async -> Void
    @ObservationIgnored var glyphs: (rows: [SpotItem], glyphs: [String]) = ([], [])
    @ObservationIgnored var link: ScriptMode
    @ObservationIgnored var answered: Date? {
        didSet { settle() }
    }
    @ObservationIgnored var lastAnswer: Frame?
    @ObservationIgnored var shownFrame: String?
    @ObservationIgnored var shownEvent: ShowEvent?
    @ObservationIgnored var finishesShow = false
    @ObservationIgnored var hasAsked = false
    @ObservationIgnored var waiter: (() -> Void)?
    @ObservationIgnored var selecting: String?
    @ObservationIgnored var showsAgain = false
    @ObservationIgnored var sheetAgain = false
    @ObservationIgnored var eventAgain: ShowEvent?
    @ObservationIgnored var pauses: [String: Task<Void, Never>] = [:]
    @ObservationIgnored var editing: String?
    @ObservationIgnored var typed: String?
    @ObservationIgnored var waitingFiles: [SpotAction] = []
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
        state = spot.headerState
        reading = MetricReading(label: spot.name, headerSymbol: spot.headerSymbol)
        isOn = spot.headerState.on == true
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
        if new.answers != spot.answers { answer("") }
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

    func restartScript() {
        link.restart()
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
            self.perLine = perLine
            self.setsApart = setsApart
            self.sections = sections
        }
    }

    func layOut() {
        if var next = parts {
            next.place(top: top)
            panel = next
        }
        settle()
    }

    func settle() {
        let next = rows.isBento
            ? Shape(rows: rows.drawing.lineCount(rows: rows.shown.count) * rows.drawing.columns, perLine: rows.drawing.columns)
            : Shape(rows: rows.lineCount, perLine: rows.perLine, setsApart: rows.setsApart, sections: rows.sectionCount)
        if next != shape { shape = next }
        let waits = showsSheet && answered == nil && panel == nil && rows.search == .local && rows.isLoading && !rows.holdsItems
        let nextKind = heardKind ?? (waits ? .waiting : panel?.kind ?? .rows)
        if nextKind != kind { kind = nextKind }
        let field = nextKind.showsField && rows.search != .off
        if field != showsField { showsField = field }
        let header = rows.perLine > 1 ? 0 : SheetHeader.shared.extra(for: shownState.subtitle)
        let nextTop = SheetTop(showsRows: panel?.showsRows ?? true, search: rows.search, header: header)
        if nextTop != top { top = nextTop }
        if var placed = panel, placed.top != nextTop {
            placed.place(top: nextTop)
            panel = placed
        }
        let rect = panel.map(SpotTokens.panelRect)
        if rect != partsRect { partsRect = rect }
        let parts = panel?.kind
        if parts != partsKind { partsKind = parts }
        let sheet = rect ?? SpotTokens.sheetRect(rows: next.rows, perLine: next.perLine, sections: next.sections, setsApart: next.setsApart, top: nextTop)
        if sheet != sheetRect { sheetRect = sheet }
    }

    func hear(_ lines: Frame?) {
        guard let lines else {
            heardKind = nil
            return
        }
        guard kind == .waiting else { return }
        heardKind = SheetKind(parts: lines.parts, layout: lines.layout)
    }
}
