import Foundation
import Observation

/// All that one script shows: its state, its value, its rows, its parts, whether its sheet is open and its
/// running calls. It reaches the script through its link, which runs a process for each call or keeps one that stays. A run
/// of one never stops a run of another, and a stopped run changes nothing.
@MainActor
@Observable
public final class SpotRun {
    /// What the sheet tells its owner.
    public enum Report: Sendable {
        case toast(String)
        case failure(String)
        /// A failure with a link that opens its fix (protocol: The life of a call).
        case failureWithFix(String, URL)
        case frame(String)
        /// The rows that a search finds, or the state, changed.
        case listChange
        /// A click on a card that takes files and has no sheet: the owner asks the person for files, and gives them to `drop`.
        case chooseFiles
        /// The float of the script closed by itself, as when its script left the folder.
        case landed
        /// The sheet closed by itself, as when the panel closed or its script left the folder.
        case closed
    }

    /// Why a read is asked. A `panel` or a `sheet` moment can use a young answer. The clock and an event always run and report
    /// no failure to a person. A change of state always runs, and runs again after a read that started before it.
    public enum ReadNeed: Sendable {
        case moment
        case clock
        case change
    }

    /// What a call asks for, which says what its answer replaces. A read of a list that the script searches carries the text
    /// it was sent with.
    enum Ask {
        /// `tells` says whether its failure shows as a toast, which a read at the opening of the panel does not (protocol: The life of a call).
        case read(generation: Int?, reports: Bool, query: String = "", tells: Bool = true)
        case search(String)
        /// The rows that answer a text of the main search, which leave the spot and its sheet as they are (protocol: Places).
        case answer(String)

        var isAnswer: Bool {
            if case .answer = self { return true }
            return false
        }
    }

    /// A call of work: the parts it answers, the part whose text the person owns, whether a read follows it, and the state
    /// that a stop brings back.
    struct Work {
        var generation: Int?
        var keeping: String?
        var readsAfter = true
        var undo: SpotState?
    }

    /// What a call is for, which says what its frames and its end change.
    enum Purpose {
        case ask(Ask)
        case work(Work)
    }

    /// One call that a run sends through its link.
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
    /// The rows that the script gave for the text of the main search, which stay until the newest text is answered (protocol: Places).
    public internal(set) var answers: [SpotItem] = []
    /// The text of the main search that the script was last asked to answer, and the text that its rows answer.
    var answerQuery = ""
    var answeredQuery = ""
    /// The work that waits for the answer to the newest text, such as a pick of a row of the older one.
    var answerWaiters: [() -> Void] = []

    /// Whether the script has not yet answered the newest text that it was asked.
    public var isAnswering: Bool {
        answeredQuery != answerQuery
    }
    @ObservationIgnored var rows: ItemList

    /// The rows of the sheet. A move of the selection alone tells only the readers of `selection` and reports nothing, so
    /// that a held arrow key redraws what shows the selection and nothing else. The owner hears of a change only when the
    /// rows that a search finds change.
    public var list: ItemList {
        get {
            access(keyPath: \.list)
            return rows
        }
        set {
            guard newValue != rows else { return }
            if newValue.differsOnlyInSelection(from: rows) {
                withMutation(keyPath: \.selection) { rows = newValue }
                return
            }
            let findsSameRows = newValue.findsSameRows(as: rows)
            if newValue.selected != rows.selected {
                withMutation(keyPath: \.selection) { withMutation(keyPath: \.list) { rows = newValue } }
            } else {
                withMutation(keyPath: \.list) { rows = newValue }
            }
            settle()
            if !findsSameRows { onReport(.listChange) }
        }
    }

    /// The index of the selected row among the shown rows.
    public var selection: Int {
        access(keyPath: \.selection)
        return rows.selected
    }

    /// The selected row, read so that a move of the selection and a change of the rows both tell its reader.
    public var selectedItem: SpotItem? {
        access(keyPath: \.list)
        access(keyPath: \.selection)
        return rows.selectedItem
    }
    @ObservationIgnored private var parts: SheetParts?
    /// The parts of the sheet. A move of the selection alone tells only the readers of `selectedPart`, so that an arrow press
    /// redraws what shows the selection and not the sheet.
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
    /// The part that return uses, read so that a move of the selection and a change of the parts both tell its reader.
    public var selectedPart: SpotPart? {
        access(keyPath: \.panel)
        access(keyPath: \.selectedPart)
        return parts?.selectedPart
    }
    /// The last arrow press that asks the parts to scroll. It lives apart from the parts, so that a press redraws only the scroll.
    public internal(set) var nudge = SheetParts.Nudge.rest
    /// The last press of return that asks the menu of a part to open. It lives apart from the parts, as the nudge does.
    public internal(set) var menuOpening: SheetParts.MenuOpening?
    /// Whether this sheet is the open one, as the runs record it.
    public var isOpen: Bool {
        runs.openID == spot.id
    }
    /// Whether the script shows in a float of its own (W7).
    public var isFloating: Bool {
        runs.floating.contains(spot.id)
    }
    /// The places where its sheet shows, as the runs record them.
    public var places: Set<SheetPlace> {
        Set([isOpen ? SheetPlace.panel : nil, isFloating ? .float : nil].compactMap { $0 })
    }
    /// Whether its sheet shows in any place.
    var showsSheet: Bool {
        !places.isEmpty
    }
    /// How many rows the list shows, and how many on a line. It changes only when they do, so a move of the selection leaves
    /// a view that sizes itself by it alone.
    public private(set) var shape = Shape(rows: 0, perLine: 1)
    /// What kind of sheet it is, from its parts, or from a first answer that waits for the open motion. An open sheet that
    /// still waits for its first answer cannot say yet.
    public private(set) var kind = SheetKind.rows
    /// The rect of its sheet of parts, and the kind of those parts. They change only when they do, so that a new value of a
    /// part reaches no view that reads only these.
    public private(set) var partsRect: CGRect?
    public private(set) var partsKind: SheetKind?
    /// The kind of the first answer while it waits for the open motion, or nil when no such answer waits.
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
    /// Whether its card is on. It changes only when that does, so that a view that shows only this hears of no other change.
    public private(set) var isOn = false
    public internal(set) var reading: MetricReading
    /// The words of its last failed call, until a call ends well.
    public internal(set) var failure: String?
    /// Each running call, the oldest first, with the last frame of each. A read starts and ends a call, so no view hears of it.
    @ObservationIgnored public internal(set) var calls: [ScriptCall] = []
    /// The calls that do work, the oldest first, which `work` shows. Only a call of work changes it.
    var workCalls: [ScriptCall] = []
    @ObservationIgnored public var onReport: (Report) -> Void = { _ in }
    /// Makes the change that brings the sheet its first parts.
    @ObservationIgnored public var partsArrival: (() -> Void) -> Void = { $0() }
    var workPauses = 0
    @ObservationIgnored let runs: SpotRuns
    /// Makes the pictures of these rows ready ahead of their first frame, with the colour glyphs of the whole list.
    @ObservationIgnored let prepare: ([SpotItem], [String]) async -> Void
    /// The glyphs of the rows that were made ready last.
    @ObservationIgnored var glyphs: (rows: [SpotItem], glyphs: [String]) = ([], [])
    @ObservationIgnored var link: ScriptLink
    @ObservationIgnored var answered: Date? {
        didSet { settle() }
    }
    @ObservationIgnored var lastAnswer: SpotOutput?
    @ObservationIgnored var hasAsked = false
    /// The work that waits for the next answer, such as a press of a card whose kind the answer says.
    @ObservationIgnored var waiter: (() -> Void)?
    @ObservationIgnored var selecting: String?
    @ObservationIgnored var readsAgain = false
    /// The newest event that came during a read, which reads again once that read ends.
    @ObservationIgnored var eventAgain: ReadReason?
    @ObservationIgnored var pauses: [String: Task<Void, Never>] = [:]
    @ObservationIgnored var editing: String?
    /// The drops and the drags of files that wait for the running work, each in turn (protocol: The calls, Files out).
    @ObservationIgnored var waitingFiles: [SpotAction] = []
    @ObservationIgnored var waitingKeys: [String] = []

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

    /// Takes the spot again after a new look at the plugin folder, with what its script last printed. A script that starts
    /// or stops staying, or that starts or stops running inline, gets a new link.
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

    /// Ends a staying script that runs, so that it starts again with the mode of the runs while something wants it, and
    /// lets an inline script load again at its next call (protocol: Trust).
    func restartScript() {
        guard spot.mode.stays || spot.mode == .inline, link.isReachable else { return }
        link.end()
        link.settle()
    }

    /// Whether a click must wait for the first answer, because the kind of this spot comes from what the script prints.
    public var awaitsAnswer: Bool {
        spot.readsState && !hasAsked
    }

    /// The rows and the line length of a list.
    public struct Shape: Equatable, Sendable {
        public let rows: Int
        public let perLine: Int

        public init(rows: Int, perLine: Int) {
            self.rows = rows
            self.perLine = perLine
        }
    }

    /// Takes the shape and the wait from the list, the parts and the answer, and stores each only when it changes.
    func settle() {
        let next = rows.isBento
            ? Shape(rows: rows.drawing.lineCount(rows: rows.shown.count) * rows.drawing.columns, perLine: rows.drawing.columns)
            : Shape(rows: rows.shown.count, perLine: rows.perLine)
        if next != shape { shape = next }
        let waits = showsSheet && answered == nil && panel == nil && rows.search == .local && rows.isLoading && !rows.holdsItems
        let nextKind = heardKind ?? (waits ? .waiting : panel?.kind ?? .rows)
        if nextKind != kind { kind = nextKind }
        let rect = panel.map(SpotTokens.panelRect)
        if rect != partsRect { partsRect = rect }
        let parts = panel?.kind
        if parts != partsKind { partsKind = parts }
    }

    /// Hears a frame that waits for the open motion, or nil when the wait ends. A sheet that waits for its first answer
    /// takes its kind from that frame while it waits.
    func hear(_ lines: SpotOutput?) {
        guard let lines else {
            heardKind = nil
            return
        }
        guard kind == .waiting else { return }
        heardKind = SheetKind(parts: lines.parts, layout: lines.layout)
    }
}
