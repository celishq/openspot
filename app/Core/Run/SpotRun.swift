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
        case listChange
        case chooseFiles
        case landed
        case closed
        case move(FlowMove)
    }

    public enum ReadNeed: Sendable {
        case moment
        case clock
        case change
    }

    enum Ask {
        case read(generation: Int?, reports: Bool, query: String = "", tells: Bool = true)
        case search(String)
        case answer(String)

        var isAnswer: Bool {
            if case .answer = self { return true }
            return false
        }
    }

    struct Work {
        var generation: Int?
        var keeping: String?
        var readsAfter = true
        var undo: SpotState?
    }

    enum Purpose {
        case ask(Ask)
        case work(Work)
    }

    struct Call {
        let action: SpotAction
        let key: String
        var input: String?
        var limit: TimeInterval?
        var reason: ReadReason?
        var variables: [String: String] = [:]
        let purpose: Purpose
    }

    static let answerAge: TimeInterval = 5
    static let textPause: Duration = .milliseconds(300)
    static let sliderPause: Duration = .milliseconds(100)
    static let pressPause: TimeInterval = 1
    static let workPause: TimeInterval = 1
    static let readKey = "read"
    static let searchKey = "search"
    static let answerKey = "answer"
    static let cardKey = "card"
    static let levelKey = "level"
    static let globalKey = "global"

    public internal(set) var spot: Spot
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

    public func landRows() {
        if rows.isFinding { list.landFinding() }
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
    @ObservationIgnored var heardKind: SheetKind? {
        didSet { settle() }
    }
    public internal(set) var state: SpotState {
        didSet {
            guard state != oldValue else { return }
            if (state.on == true) != isOn { isOn = state.on == true }
            onReport(.listChange)
        }
    }
    public private(set) var isOn = false
    public internal(set) var reading: MetricReading
    public internal(set) var failure: String?
    @ObservationIgnored public internal(set) var calls: [ScriptCall] = []
    var workCalls: [ScriptCall] = []
    @ObservationIgnored public var onReport: (Report) -> Void = { _ in }
    @ObservationIgnored public var partsArrival: (() -> Void) -> Void = { $0() }
    var workPauses = 0
    @ObservationIgnored let runs: SpotRuns
    @ObservationIgnored let prepare: ([SpotItem], [String]) async -> Void
    @ObservationIgnored var glyphs: (rows: [SpotItem], glyphs: [String]) = ([], [])
    @ObservationIgnored var link: ScriptLink
    @ObservationIgnored var answered: Date? {
        didSet { settle() }
    }
    @ObservationIgnored var lastAnswer: SpotOutput?
    @ObservationIgnored var readReason: ReadReason?
    @ObservationIgnored var finishesRead = false
    @ObservationIgnored var hasAsked = false
    @ObservationIgnored var waiter: (() -> Void)?
    @ObservationIgnored var selecting: String?
    @ObservationIgnored var readsAgain = false
    @ObservationIgnored var eventAgain: ReadReason?
    @ObservationIgnored var pauses: [String: Task<Void, Never>] = [:]
    @ObservationIgnored var editing: String?
    @ObservationIgnored var waitingFiles: [SpotAction] = []
    @ObservationIgnored var waitingKeys: [String] = []
    public internal(set) var page: String?
    @ObservationIgnored var pageStates: [(page: String?, state: PageState)] = []

    init(spot: Spot, runs: SpotRuns, recent: [String], prepare: @escaping ([SpotItem], [String]) async -> Void) {
        self.spot = spot
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

    private static func link(for spot: Spot, runs: SpotRuns) -> ScriptLink {
        switch spot.mode {
        case .once: OnceLink(runs: runs)
        case .stay, .always: StayLink(runs: runs)
        case .inline: InlineLink(runs: runs)
        }
    }

    public func update(_ new: Spot) {
        let header = spot.headerState
        if new.answers != spot.answers { answer("") }
        if new.mode.stays != spot.mode.stays || (new.mode == .inline) != (spot.mode == .inline) {
            let old = link
            link = Self.link(for: new, runs: runs)
            link.run = self
            old.end()
        }
        spot = lastAnswer.map(new.taking) ?? new
        if reading.label != new.name || reading.headerSymbol != new.headerSymbol {
            reading = MetricReading(label: new.name, headerSymbol: new.headerSymbol)
        }
        if new.headerState != header { takeState(lastAnswer) }
    }

    func restartScript() {
        guard spot.mode.stays || spot.mode == .inline, link.isReachable else { return }
        link.end()
        link.settle()
    }

    public var awaitsAnswer: Bool {
        spot.readsState && !hasAsked
    }

    public struct Shape: Equatable, Sendable {
        public let rows: Int
        public let perLine: Int
        public let hasField: Bool
        public let setsApart: Bool

        public init(rows: Int, perLine: Int, hasField: Bool = true, setsApart: Bool = false) {
            self.rows = rows
            self.perLine = perLine
            self.hasField = hasField
            self.setsApart = setsApart
        }
    }

    func settle() {
        let next = rows.isBento
            ? Shape(rows: rows.drawing.lineCount(rows: rows.shown.count) * rows.drawing.columns, perLine: rows.drawing.columns)
            : Shape(rows: rows.shown.count, perLine: rows.perLine, hasField: rows.search != .off, setsApart: rows.setsApart)
        if next != shape { shape = next }
        let waits = showsSheet && answered == nil && panel == nil && rows.search == .local && rows.isLoading && !rows.holdsItems
        let nextKind = heardKind ?? (waits ? .waiting : panel?.kind ?? .rows)
        if nextKind != kind { kind = nextKind }
        let rect = panel.map(SpotTokens.panelRect)
        if rect != partsRect { partsRect = rect }
        let parts = panel?.kind
        if parts != partsKind { partsKind = parts }
        let sheet = rect ?? SpotTokens.sheetRect(rows: next.rows, perLine: next.perLine, hasField: next.hasField, setsApart: next.setsApart)
        if sheet != sheetRect { sheetRect = sheet }
        let field = nextKind.showsField && rows.search != .off
        if field != showsField { showsField = field }
    }

    func hear(_ lines: SpotOutput?) {
        guard let lines else {
            heardKind = nil
            return
        }
        guard kind == .waiting else { return }
        heardKind = SheetKind(parts: lines.parts, layout: lines.layout)
    }
}
