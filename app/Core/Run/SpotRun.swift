import Foundation
import Observation

/// All that one script shows: its last frame, its state, its value, its rows, its parts, whether its sheet is open and its
/// running calls. It reaches the script through its link, which runs a process for each call or keeps one that stays. A run
/// of one never stops a run of another, and a stopped run changes nothing.
@MainActor
@Observable
public final class SpotRun {
    /// What the sheet tells its owner.
    public enum Report: Sendable {
        case toast(String)
        case failure(String)
        /// A failure with a link that opens its fix (R9).
        case failureWithFix(String, URL)
        case frame(String)
        /// The rows that a search finds, or the state, changed.
        case listChange
        /// A click on a card that takes files and has no sheet: the owner asks the person for files, and gives them to `drop`.
        case chooseFiles
        /// The sheet closed by itself, as when the panel closed or its script left the folder.
        case closed
    }

    /// Why a read is asked. A `panel` or a `sheet` moment can use a young answer. The clock always runs and reports no failure
    /// to a person. A change of state always runs, and runs again after a read that started before it.
    public enum ReadNeed: Sendable {
        case moment
        case clock
        case change
    }

    /// What a call asks for, which says what its answer replaces.
    enum Ask {
        case read(generation: Int?, reports: Bool)
        case search(String)
    }

    /// Where a frame that answers nothing comes from: a later frame of a read, or a frame of any other call.
    enum Source {
        case read
        case call(generation: Int?, keeping: String?)
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

    private static let answerAge: TimeInterval = 5
    private static let textPause: Duration = .milliseconds(300)
    private static let sliderPause: Duration = .milliseconds(100)
    private static let pressPause: TimeInterval = 1
    private static let workPause: TimeInterval = 1
    private static let readKey = "read"
    private static let searchKey = "search"
    private static let cardKey = "card"
    private static let levelKey = "level"
    private static let heldKey = "held"
    private static let globalKey = "global"

    public private(set) var command: Spot
    @ObservationIgnored private var rows: ItemList

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
    public private(set) var panel: SheetParts? {
        didSet { settle() }
    }
    /// The last arrow press that asks the parts to scroll. It lives apart from the parts, so that a press redraws only the scroll.
    public private(set) var nudge = SheetParts.Nudge.rest
    /// Whether this sheet is the open one, as the runs record it.
    public var isOpen: Bool {
        runs.openID == command.id
    }
    /// How many rows the list shows, and how many on a line. It changes only when they do, so a move of the selection leaves
    /// a view that sizes itself by it alone.
    public private(set) var shape = Shape(rows: 0, perLine: 1)
    /// Whether an open sheet still waits for the first answer, so that it cannot yet say what kind of sheet it is.
    public private(set) var awaitsFirstAnswer = false
    public private(set) var state: SpotState {
        didSet { if state != oldValue { onReport(.listChange) } }
    }
    public private(set) var reading: MetricReading
    public private(set) var lastFrame: String?
    /// Each running call, the oldest first, with the last frame of each.
    public private(set) var calls: [ScriptCall] = []
    @ObservationIgnored public var onReport: (Report) -> Void = { _ in }
    /// Makes the change that brings the sheet its first parts.
    @ObservationIgnored public var partsArrival: (() -> Void) -> Void = { $0() }
    private var workPauses = 0
    @ObservationIgnored private let runs: SpotRuns
    @ObservationIgnored private let prepare: ([SpotItem]) async -> Void
    @ObservationIgnored private var link: ScriptLink
    @ObservationIgnored private var answered: Date? {
        didSet { settle() }
    }
    @ObservationIgnored private var lastAnswer: PluginOutput?
    @ObservationIgnored private var hasAsked = false
    /// The work that waits for the next answer, such as a press of a card whose kind the answer says.
    @ObservationIgnored private var waiter: (() -> Void)?
    /// The open that waits for the sheet's first answer.
    @ObservationIgnored private var held: (() -> Void)?
    @ObservationIgnored private var selecting: String?
    @ObservationIgnored private var readsAgain = false
    @ObservationIgnored private var pauses: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var editing: String?
    @ObservationIgnored private var waitingDrops: [[String]] = []
    @ObservationIgnored private var waitingKeys: [String] = []

    init(command: Spot, runs: SpotRuns, recent: [String], prepare: @escaping ([SpotItem]) async -> Void) {
        self.command = command
        self.runs = runs
        self.prepare = prepare
        link = Self.link(for: command, runs: runs)
        rows = ItemList(recent: recent)
        state = command.headerState
        reading = MetricReading(label: command.name, headerSymbol: command.headerSymbol)
        settle()
        link.run = self
    }

    nonisolated deinit {}

    private static func link(for command: Spot, runs: SpotRuns) -> ScriptLink {
        command.stays ? StayLink(runs: runs) : OnceLink(runs: runs)
    }

    /// Takes the command again after a new look at the plugin folder, with what its script last printed. A script that starts
    /// or stops staying gets a new link.
    public func update(_ new: Spot) {
        let header = command.headerState
        if new.stays != command.stays {
            let old = link
            link = Self.link(for: new, runs: runs)
            link.run = self
            old.end()
        }
        command = lastAnswer.map(new.taking) ?? new
        if reading.label != new.name || reading.headerSymbol != new.headerSymbol {
            reading = MetricReading(label: new.name, headerSymbol: new.headerSymbol)
        }
        if new.headerState != header { takeState(lastAnswer) }
    }

    /// Whether a click must wait for the first answer, because the kind of this spot comes from what the script prints.
    public var awaitsAnswer: Bool {
        command.readsState && !hasAsked
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
    private func settle() {
        let next = rows.isBento
            ? Shape(rows: rows.drawing.lineCount(rows: rows.shown.count) * rows.drawing.columns, perLine: rows.drawing.columns)
            : Shape(rows: rows.perLine == 1 ? rows.spans : rows.shown.count, perLine: rows.perLine)
        if next != shape { shape = next }
        let waits = isOpen && answered == nil && panel == nil && rows.search == .local && rows.isLoading && !rows.holdsItems
        if waits != awaitsFirstAnswer { awaitsFirstAnswer = waits }
    }

    /// Asks for the first answer, and runs the given work when it arrives.
    public func afterAnswer(_ work: @escaping () -> Void) {
        waiter = work
        read()
    }

    /// Opens the sheet with its search kept. A sheet with a young answer opens at once with its parts. One with no answer
    /// runs `onReady` with its first answer: with `waits`, or after a short pause when that is late, and always for a script
    /// that holds its own state, which does not open when it cannot start.
    public func open(need: ReadNeed = .moment, waits: Bool = false, onReady: @escaping () -> Void) {
        runs.willOpen(self)
        settle()
        list.selectFirst()
        if panel == nil, answered != nil { panel = lastAnswer.flatMap(SheetParts.init(output:)) }
        if answered == nil, command.stays || (waits && list.search == .local) {
            held = onReady
            if !command.stays { after(.seconds(runs.firstAnswerPause), key: Self.heldKey) { [weak self] in self?.endHold() } }
        } else {
            onReady()
        }
        read(need: need)
        if !link.isReachable { dropUnshownSheet() }
        runs.updateClock()
    }

    /// Stops what only an open sheet needs. A read that nothing else wants stops. A call that does work goes on.
    public func close() {
        guard isOpen else { return }
        runs.didClose(self)
        settle()
        for (key, pause) in pauses where key != Self.levelKey {
            pause.cancel()
            pauses[key] = nil
        }
        if let search = running(Self.searchKey) { stop(search) }
        editing = nil
        held = nil
        panel?.clearSelection()
        link.settle()
        stopUnwantedRead()
        runs.updateClock()
    }

    /// Moves the selection among its parts.
    public func movePart(by step: Int) {
        panel?.move(by: step)
    }

    public func scrollPanel(by step: Int) {
        nudge = SheetParts.Nudge(step: step, serial: nudge.serial + 1)
    }

    /// The panel closed: a sheet of parts, or of a script that holds its own state, closes and drops its values, so the next
    /// open reads again. A sheet of rows stays.
    func panelClosed() {
        if panel != nil || command.stays {
            let wasOpen = isOpen
            close()
            panel = nil
            answered = nil
            if wasOpen { onReport(.closed) }
        }
        stopUnwantedRead()
        link.settle()
    }

    /// The panel opened: an open sheet of rows is in view again and reads, by M1 and M2.
    func panelOpened() {
        if isOpen { read() }
        link.settle()
    }

    /// A scan looked at the folder: a stopped script that changed can start again (Y5).
    func scanned() {
        link.scanned()
    }

    /// Stops each read of this script, whose sheet no longer has a use for it, and ends the script.
    func stopReads() {
        if let read = running(Self.readKey) { stop(read) }
        link.end()
    }

    /// Whether the person sees this sheet: it is the open one, and the panel shows.
    private var isInView: Bool {
        isOpen && runs.isPanelOpen
    }

    /// Whether something wants this script now (L3), also a call of a staying script that waits for its `end`.
    var isWanted: Bool {
        isInView || runs.wants(command) || link.holdsScript
    }

    /// Starts a script that stays and that something wants, and ends one that nothing wants.
    func settleScript() {
        link.settle()
    }

    /// Stops each call and lets go of the script, so that neither changes anything, and drops all that would start a new call.
    func prepareToQuit() {
        pauses.values.forEach { $0.cancel() }
        pauses = [:]
        waitingDrops = []
        waitingKeys = []
        readsAgain = false
        calls.forEach(stop)
        link.leave()
    }

    /// Asks the script for what it shows. A list that the script searches asks its search. A request joins the read that
    /// runs, and a change reads again after it (M1). A `panel` or a `sheet` moment uses an answer younger than 5 seconds (M2).
    /// A file with no `read` gets its click instead.
    public func read(selecting run: String? = nil, need: ReadNeed = .moment, reason: ReadReason? = nil) {
        let reason = reason ?? (need == .change ? .change : isOpen ? .sheet : .panel)
        if let run { selecting = run }
        guard list.search == .local || command.stays else { return ask() }
        if link.isAsking {
            if need == .change { readsAgain = true }
            return
        }
        if need == .moment, let answered, runs.now().timeIntervalSince(answered) < Self.answerAge {
            selectKept()
            showRunning()
            return
        }
        let action = command.read == nil ? command.click : SpotAction.read
        let isSent = link.send(Call(
            action: action,
            key: Self.readKey,
            input: isOpen ? panel?.values : nil,
            limit: action == .read ? runs.readLimit : nil,
            reason: reason,
            variables: action == .read ? reason.variables : [:],
            purpose: .ask(.read(generation: panel?.generation, reports: need != .clock))
        ))
        if isSent { list.beginLoading() }
    }

    /// Takes new text in the search. A newer search stops the older one, and the script hears after a pause.
    public func search(_ text: String) {
        guard list.search(text), list.search == .script else { return }
        if let older = running(Self.searchKey) { stop(older) }
        after(Self.textPause, key: Self.searchKey) { [weak self] in self?.ask() }
    }

    /// Takes a value the person set, so that it shows at once, and tells the script after a pause that fits the control. It
    /// stops the older call of this part.
    public func set(_ part: SpotPart, to value: String) {
        guard let generation = panel?.set(value, of: part.id) else { return }
        if part.isEditable { editing = part.id }
        let key = Self.key(part: part.id)
        if let older = running(key) { stop(older) }
        let keeping = part.isEditable ? part.id : nil
        let action = SpotAction.set(part.id, to: value)
        let send: () -> Void = { [weak self] in self?.change(action, key: key, generation: generation, keeping: keeping, closes: false) }
        switch part.control {
        case .text: after(Self.textPause, key: key, send)
        case .slider: after(Self.sliderPause, key: key, send)
        default:
            pauses[key]?.cancel()
            send()
        }
    }

    /// Runs a press of a part. A second press of a running part stops its call.
    public func press(_ part: SpotPart) {
        let key = Self.key(part: part.id)
        if let running = running(key) { return pressAgain(running) }
        guard let generation = panel?.advance() else { return }
        editing = nil
        change(.press(part.id), key: key, generation: generation, keeping: nil, closes: part.closes)
    }

    /// Whether a read or a search of this script waits for its answer.
    var isReading: Bool {
        link.isAsking
    }

    /// Whether a call of the card runs.
    public var isCardRunning: Bool {
        running(Self.cardKey) != nil
    }

    /// The calls that show as running work: each one that does work and has run for 1 second, the oldest first (L6). A new
    /// one shows by itself, because `workPauses` changes when its second has passed.
    public var work: [ScriptCall] {
        _ = workPauses
        let time = runs.now()
        return calls.filter { $0.doesWork && time.timeIntervalSince($0.started) >= Self.workPause }
    }

    /// The call of the card, once it shows, which a press of the card stops.
    public var cardWork: ScriptCall? {
        shown(Self.cardKey)
    }

    /// The call of this part, once it shows.
    public func work(of part: SpotPart) -> ScriptCall? {
        shown(Self.key(part: part.id))
    }

    /// The call that a press of this row of the actions menu stops, once it shows.
    public func work(of row: ActionMenu.Row, item: SpotItem?) -> ScriptCall? {
        if let action = row.action { return shown(Self.key(call: .action(action, item: item))) }
        return shown(item.map { Self.key(call: .item($0)) } ?? Self.cardKey)
    }

    /// What the spot shows: its own state, with the words of its oldest running work over it while that runs (G4).
    public var shownState: SpotState {
        guard let call = work.first else { return state }
        return state.showing(title: call.title, detail: call.detail)
    }

    /// Runs a click on a card with no sheet: a toggle shows its new state at once, and a card that takes files asks for a
    /// choice. A second press stops the call, and a stopped toggle goes back.
    public func pressCard() {
        if let running = running(Self.cardKey) { return pressAgain(running) }
        if command.kind == .launch, command.takesDrops { return onReport(.chooseFiles) }
        guard command.kind == .toggle else { return work(command.click, key: Self.cardKey) }
        let before = state
        let action = SpotAction.toggle(state)
        state = state.switched(on: !(state.on ?? false))
        work(action, key: Self.cardKey, as: Work(undo: before))
    }

    /// Takes a change or a press of a component that the card draws (U5). The card shows a new value at once, and the call
    /// sends `<id> [value]`.
    public func setCardPart(_ id: String, to value: String?) {
        guard let value else { return work(.press(id), key: Self.key(part: id)) }
        state = state.setting(value, of: id)
        work(.set(id, to: value), key: Self.key(part: id))
    }

    /// Takes files that a person dropped or chose, and returns whether the card takes them. They run as one `drop` call, once
    /// no call that does work runs. A running call goes on.
    @discardableResult
    public func drop(_ paths: [String]) -> Bool {
        guard command.accepts(paths) else { return false }
        waitingDrops.append(paths)
        startWaitingDrop()
        return true
    }

    private func startWaitingDrop() {
        guard !waitingDrops.isEmpty, !calls.contains(where: \.doesWork) else { return }
        work(.drop(paths: waitingDrops.removeFirst()), key: Self.cardKey)
    }

    /// Takes a press of a key that a person assigned to a command. Presses run one at a time and in order, and none stops a call.
    public func pressKey(_ call: String) {
        waitingKeys.append(call)
        startWaitingKey()
    }

    private func startWaitingKey() {
        guard !waitingKeys.isEmpty, running(Self.globalKey) == nil else { return }
        work(.press(waitingKeys.removeFirst()), key: Self.globalKey)
    }

    /// Takes a new level of a slider on a card, which shows at once and reaches the script after a pause.
    public func setLevel(_ value: Double) {
        let next = state.withLevel(value)
        guard next.level != state.level else { return }
        state = next
        if let older = running(Self.levelKey) { stop(older) }
        after(Self.sliderPause, key: Self.levelKey) { [weak self] in
            guard let self else { return }
            work(.level(state.level ?? 0, of: state.control ?? ""), key: Self.levelKey)
        }
    }

    /// Runs a pick of a row. A second pick of a running row stops its call.
    public func pick(_ item: SpotItem) {
        press(.item(item))
    }

    /// Takes a key that the person recorded on a row, and tells the script.
    public func set(_ item: SpotItem, to value: String) {
        press(.set(item.run, to: value))
    }

    /// Takes a value that the person set in a slot of a row, shows it at once, and tells the script (U9, U10).
    public func set(slot: String, of item: SpotItem, to value: String) {
        list.set(value, of: slot, in: item.run)
        press(.slot(slot, run: item.run, value: value))
    }

    /// Runs a press of a button in a slot of a row (U9). A second press of a running one stops its call.
    public func press(slot: String, of item: SpotItem) {
        press(.slot(slot, run: item.run))
    }

    /// Runs an action. A second press of a running action stops its call.
    public func run(_ action: CommandAction, item: SpotItem?) {
        press(.action(action, item: item))
    }

    /// Asks for the form of an action: the call of that action, with empty stdin. Returns nil when a person pressed it again.
    public func form(_ action: CommandAction, item: SpotItem?) async throws -> ItemForm? {
        let call = SpotAction.action(action, item: item)
        let key = Self.key(call: call)
        if let running = running(key) {
            pressAgain(running)
            return nil
        }
        guard let text = try await link.form(call, key: key) else { return nil }
        guard let form = ItemForm(output: PluginOutput(text: text)) else { throw PluginError.badForm }
        return form
    }

    /// Runs an action that can ask with a form first, such as the change of a setting. Returns the form it answers with, or
    /// done, and nil when a person pressed it again.
    public func change(_ action: CommandAction) async throws -> FormAnswer? {
        let call = SpotAction.action(action, item: nil)
        let key = Self.key(call: call)
        if let running = running(key) {
            pressAgain(running)
            return nil
        }
        guard let text = try await link.form(call, key: key) else { return nil }
        if let form = ItemForm(output: PluginOutput(text: text)), !form.fields.isEmpty { return .form(form) }
        read(need: .change)
        return .done
    }

    /// Gives a filled form to the script, and reads again with the row it saved selected. A script that answers with a form
    /// asks again. Returns nil when a person pressed it again.
    public func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft) async throws -> FormAnswer? {
        let call = SpotAction.action(action, item: item)
        let key = Self.key(call: call)
        if let running = running(key) {
            pressAgain(running)
            return nil
        }
        guard let text = try await link.submit(call, key: key, values: draft.text) else { return nil }
        guard !command.stays else { return .done }
        if let form = ItemForm(output: PluginOutput(text: text)), !form.fields.isEmpty { return .form(form) }
        let run = text.trimmingCharacters(in: .whitespacesAndNewlines)
        read(selecting: run.isEmpty ? nil : run, need: .change)
        return .done
    }

    /// Stops a running call: it gets the terminate signal and 2 seconds, and it changes nothing. A call of a staying script
    /// gets a `stop` block instead.
    public func stop(_ call: ScriptCall) {
        call.stop()
        calls.removeAll { $0 === call }
        link.stop(call)
    }

    /// Takes a press of a running call: it stops the call, unless the call started within the last second (L11).
    private func pressAgain(_ call: ScriptCall) {
        if runs.now().timeIntervalSince(call.started) >= Self.pressPause { stop(call) }
    }

    private static func key(part id: String) -> String {
        "part:\(id)"
    }

    private static func key(call action: SpotAction) -> String {
        "call:\(action.arguments.joined(separator: "\n"))"
    }

    private func shown(_ key: String) -> ScriptCall? {
        work.first { $0.key == key }
    }

    private func running(_ key: String) -> ScriptCall? {
        calls.first { $0.key == key }
    }

    private func stopUnwantedRead() {
        guard !isWanted else { return }
        if let read = running(Self.readKey) { stop(read) }
        if let search = running(Self.searchKey) { stop(search) }
    }

    /// Runs the work after the pause. A new request with the same key replaces it.
    private func after(_ pause: Duration, key: String, _ work: @escaping () -> Void) {
        pauses[key]?.cancel()
        pauses[key] = Task { [weak self] in
            try? await Task.sleep(for: pause)
            guard !Task.isCancelled else { return }
            self?.pauses[key] = nil
            work()
        }
    }

    /// Lists a call that the link started, and shows it as running work once its second has passed.
    func track(_ call: ScriptCall) {
        calls.append(call)
        guard call.doesWork else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.workPause))
            self?.workPauses += 1
        }
    }

    /// Lets go of a call that ended, and starts a drop or a key press that waited for it.
    func callEnded(_ call: ScriptCall) {
        calls.removeAll { $0 === call }
        startWaitingDrop()
        startWaitingKey()
    }

    /// Takes the end of a call. A read or a search that ended with no answer changes nothing when it was stopped, and tells
    /// of its failure. A call of work that ended is followed by a read: with the row that a `select` effect named selected
    /// (D8), or else when it showed nothing (M4). A stopped toggle goes back.
    func ended(_ call: ScriptCall, _ purpose: Purpose, _ end: ScriptCall.End, hadAnswer: Bool, showedParts: Bool, selected: String?) {
        switch (purpose, end) {
        case (.ask(.read), .stopped):
            list.stopLoading()
            if !hadAnswer {
                waiter = nil
                readsAgain = false
            }
        case (.ask(.read(_, let reports)), .failed(let error)):
            answered = nil
            list.loadFailed()
            changeReading { $0.markStale() }
            answerArrived()
            if reports { fail(error) }
        case (.ask(.search(let query)), .failed(let error)):
            list.stopWaiting(for: query)
            answerArrived()
            if error as? PluginError != .timedOut { fail(error) }
        case (.work(let work), .stopped):
            if let undo = work.undo { state = undo }
        case (.work(let work), .ended):
            answered = nil
            if let selected, command.read != nil {
                read(selecting: selected, need: .change)
            } else if !showedParts, work.readsAfter {
                readOnce()
            }
        case (.work(let work), .failed(let error)):
            answered = nil
            if let undo = work.undo { state = undo }
            fail(error)
            if work.readsAfter { readOnce() }
        default:
            break
        }
        callEnded(call)
        readAgainIfAsked()
    }

    /// The script that held its own state ended by itself: its value dims, its answer is old, and a sheet that waited for it
    /// closes.
    func lost() {
        scriptEnded()
        changeReading { $0.markStale() }
        dropUnshownSheet()
    }

    /// Openspot ended the script that held its own state: its answer is old, so the next open waits for a new one.
    func scriptEnded() {
        answered = nil
        list.stopLoading()
    }

    /// Takes the answer of a read or of a search: the first frame of a read that runs once, the silence of one that ended by
    /// itself, or the frame that ends a call of a staying script. A read's answer replaces all that the spot shows, and a
    /// search's answer replaces its rows (02, Y7).
    func takeAnswer(_ lines: PluginOutput, frame: String, to ask: Ask) async {
        lastFrame = frame
        lastAnswer = lines
        report(toastOf: lines)
        command = command.taking(lines)
        switch ask {
        case .read(let generation, _):
            answered = runs.now()
            if command.readsState { takeState(lines) }
            takeValue(lines)
            let kept = selecting
            selecting = nil
            changeList {
                $0.take(search: lines.search)
                $0.take(drawing: lines.drawing, templates: lines.templates)
                $0.replace(lines.items)
                if let kept { $0.select(run: kept) }
            }
            if isOpen || panel != nil { takePanel(lines, generation: generation) }
            if list.search == .script, !list.query.isEmpty { self.ask() }
            showRunning()
        case .search(let query):
            await prepare(lines.items)
            guard query == list.query else { return }
            changeList {
                $0.take(search: lines.search)
                $0.take(drawing: lines.drawing, templates: lines.templates)
                $0.answer(lines.items, to: query)
            }
        }
        answerArrived()
        readAgainIfAsked()
        onReport(.frame(frame))
        guard case .read = ask else { return }
        await prepare(lines.items)
        if command.hasSpot, !lines.errors.isEmpty {
            onReport(.failure("\(command.name) sent \(lines.errors.count) items Openspot cannot read."))
        }
    }

    /// Takes a frame that answers nothing: a later frame of a read, a frame of another call, or a frame that a staying script
    /// printed by itself. It changes only what it prints (02, Y7): the value when it prints the main component, the rows, the
    /// parts, and the control of the card. Only a later frame of a read changes the spot's words.
    func takeUpdate(_ lines: PluginOutput, frame: String, from source: Source) async {
        lastFrame = frame
        report(toastOf: lines)
        if let main = lastAnswer?.value?.fields.first?.value, lines.value?.fields.first?.value == main, let value = MetricValue(output: lines) {
            changeReading { $0.take(value) }
        }
        if case .read = source, command.readsState, lines.summary != nil {
            takeState(lines)
        } else {
            state = keepingLevel(state.taking(lines))
        }
        if !lines.items.isEmpty { list.replace(lines.items) }
        if isOpen {
            switch source {
            case .read: panel?.merge(lines, keeping: editing)
            case .call(let generation, let keeping): panel?.merge(lines, answering: generation, keeping: keeping ?? editing)
            }
        }
        onReport(.frame(frame))
        if !lines.items.isEmpty { await prepare(lines.items) }
    }

    private func takeState(_ lines: PluginOutput?) {
        guard let lines, let next = try? command.state(of: lines) else {
            if lines == nil { state = command.headerState }
            return
        }
        state = keepingLevel(next)
    }

    /// The state with the level that the person set, while the call of that level waits or runs.
    private func keepingLevel(_ next: SpotState) -> SpotState {
        guard running(Self.levelKey) != nil || pauses[Self.levelKey] != nil, let level = state.level else { return next }
        return next.withLevel(level)
    }

    private func takeValue(_ lines: PluginOutput) {
        if let value = MetricValue(output: lines) {
            changeReading { $0.take(value) }
        } else {
            changeReading { $0.markStale() }
        }
    }

    /// Shows the toast of a frame.
    func report(toastOf lines: PluginOutput) {
        if let text = lines.toast { onReport(.toast(text)) }
    }

    private func changeReading(_ change: (inout MetricReading) -> Void) {
        var next = reading
        change(&next)
        reading = next
    }

    private func changeList(_ change: (inout ItemList) -> Void) {
        var next = rows
        change(&next)
        list = next
    }

    private func selectKept() {
        guard let run = selecting else { return }
        selecting = nil
        list.select(run: run)
    }

    private func answerArrived() {
        hasAsked = true
        let work = waiter
        waiter = nil
        work?()
        endHold()
    }

    /// Reads again when a change came during a read, once no read or search waits.
    private func readAgainIfAsked() {
        guard readsAgain, !link.isAsking else { return }
        readsAgain = false
        read(need: .change)
    }

    /// Lets a sheet that held its motion move.
    private func endHold() {
        pauses[Self.heldKey]?.cancel()
        pauses[Self.heldKey] = nil
        let work = held
        held = nil
        work?()
    }

    /// Closes a sheet that waits for an answer that will not come.
    private func dropUnshownSheet() {
        guard held != nil else { return }
        held = nil
        runs.didClose(self)
        settle()
        runs.updateClock()
        onReport(.closed)
    }

    /// Shows the parts a script printed. An answer that a newer change outdated does not show.
    private func takePanel(_ lines: PluginOutput, generation: Int?) {
        if lines.parts.isEmpty {
            panel = nil
        } else if let current = panel?.generation {
            panel?.take(lines, answering: generation ?? current)
        } else {
            partsArrival { panel = SheetParts(output: lines) }
        }
    }

    /// Adds the last frame of each running call to an open sheet (L7).
    private func showRunning() {
        guard isOpen else { return }
        for call in calls where call.doesWork {
            if let lines = call.output { panel?.merge(lines, keeping: editing) }
        }
    }

    /// Asks the script about the current search. A newer search stops the older one. This never waits: `search` holds the
    /// pause.
    private func ask() {
        let query = list.query
        if let older = running(Self.searchKey) { stop(older) }
        pauses[Self.searchKey]?.cancel()
        pauses[Self.searchKey] = nil
        link.send(Call(
            action: .items(query: query, forms: SearchQuery(text: query).forms),
            key: Self.searchKey,
            limit: runs.readLimit,
            reason: .search,
            variables: ReadReason.search.variables,
            purpose: .ask(.search(query))
        ))
    }

    /// Runs one change of a sheet of parts. Only the newest answer replaces the sheet.
    private func change(_ action: SpotAction, key: String, generation: Int, keeping: String?, closes: Bool) {
        guard let values = panel?.values else { return }
        work(action, key: key, input: values, as: Work(generation: generation, keeping: keeping, readsAfter: !closes))
    }

    /// Starts or stops the call of a person's press.
    private func press(_ action: SpotAction) {
        let key = Self.key(call: action)
        if let running = running(key) { return pressAgain(running) }
        work(action, key: key)
    }

    /// Runs a call that does work. It has no time limit, and it goes on with the sheet and the panel closed. A stopped call
    /// changes nothing. After one that ended with no parts to show, a script that runs once is read once (M4).
    private func work(_ action: SpotAction, key: String, input: String? = nil, as work: Work = Work()) {
        answered = nil
        link.send(Call(action: action, key: key, input: input, purpose: .work(work)))
    }

    private func readOnce() {
        if command.read != nil { read(need: .change) }
    }

    /// Tells the person about a failed call: the script's own message when it gave one, or else what Openspot saw.
    func fail(_ error: Error) {
        let text = switch error as? PluginError {
        case .failed(_, let message) where !message.isEmpty, .failedWithFix(_, let message, _) where !message.isEmpty: message
        case .timedOut: "\(command.name) took too long, so Openspot stopped it."
        case let error?: "\(command.name) failed. \(error.reason)"
        case nil: "\(command.name) failed. \(error.localizedDescription)"
        }
        if case .failedWithFix(_, _, let fix) = error as? PluginError { return onReport(.failureWithFix(text, fix)) }
        onReport(.failure(text))
    }
}
