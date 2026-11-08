import Foundation
import Observation

/// All that one script shows: its last frame, its state, its value, its rows, its parts, whether its sheet is open and its
/// running calls. A run of one never stops a run of another, and a stopped run changes nothing.
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
        case listChange
        /// A click on a card that takes files and has no sheet: the owner asks the person for files, and gives them to `drop`.
        case chooseFiles
    }

    /// Why a read is asked. A `panel` or a `sheet` moment can use a young answer. The clock always runs and reports no failure
    /// to a person. A change of state always runs, and runs again after a read that started before it.
    public enum ReadNeed: Sendable {
        case moment
        case clock
        case change
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

    /// The rows of the sheet. A move of the selection alone tells only the readers of `selection`, so that a held arrow key
    /// redraws what shows the selection and nothing else.
    public var list: ItemList {
        get {
            access(keyPath: \.list)
            return rows
        }
        set {
            let moved = newValue.selected != rows.selected
            if newValue.differsOnlyInSelection(from: rows) {
                withMutation(keyPath: \.selection) { rows = newValue }
            } else if moved {
                withMutation(keyPath: \.selection) { withMutation(keyPath: \.list) { rows = newValue } }
            } else {
                withMutation(keyPath: \.list) { rows = newValue }
            }
            settle()
            onReport(.listChange)
        }
    }

    /// The index of the selected row among the shown rows.
    public var selection: Int {
        access(keyPath: \.selection)
        return rows.selected
    }
    public private(set) var panel: SheetParts? {
        didSet { settle() }
    }
    /// The last arrow press that asks the parts to scroll. It lives apart from the parts, so that a press redraws only the scroll.
    public private(set) var nudge = SheetParts.Nudge.rest
    public private(set) var isOpen = false {
        didSet { settle() }
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
    private var workPauses = 0
    @ObservationIgnored private let runs: SpotRuns
    @ObservationIgnored private let prepare: ([SpotItem]) async -> Void
    @ObservationIgnored private var answered: Date? {
        didSet { settle() }
    }
    @ObservationIgnored private var lastAnswer: PluginOutput?
    @ObservationIgnored private var hasAsked = false
    @ObservationIgnored private var waiter: (() -> Void)?
    @ObservationIgnored private var selecting: String?
    @ObservationIgnored private var readsAgain = false
    @ObservationIgnored private var pauses: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var isInView = false
    @ObservationIgnored private var editing: String?
    @ObservationIgnored private var held: (() -> Void)?
    @ObservationIgnored private var waitingDrops: [[String]] = []
    @ObservationIgnored private var waitingKeys: [String] = []

    init(command: Spot, runs: SpotRuns, recent: [String], prepare: @escaping ([SpotItem]) async -> Void) {
        self.command = command
        self.runs = runs
        self.prepare = prepare
        rows = ItemList(recent: recent)
        state = command.headerState
        reading = MetricReading(label: command.name, headerSymbol: command.headerSymbol)
        settle()
    }

    nonisolated deinit {}

    /// Takes the command again after a new look at the plugin folder, with what its script last printed.
    public func update(_ new: Spot) {
        let header = command.headerState
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
        let next = Shape(rows: list.shown.count, perLine: list.perLine)
        if next != shape { shape = next }
        let waits = isOpen && answered == nil && panel == nil && list.search == .local && list.isLoading && !list.holdsItems
        if waits != awaitsFirstAnswer { awaitsFirstAnswer = waits }
    }

    /// Asks for the first answer, and runs the given work when it arrives.
    public func afterAnswer(_ work: @escaping () -> Void) {
        waiter = work
        read()
    }

    /// Opens the sheet with its search kept, and runs `onReady` now. With `waits`, a sheet with no answer yet runs `onReady`
    /// with its first answer, or after a short pause when that is late.
    public func open(need: ReadNeed = .moment, waits: Bool = false, onReady: @escaping () -> Void) {
        isOpen = true
        isInView = true
        list.selectFirst()
        if waits, answered == nil, list.search == .local {
            held = onReady
            after(.seconds(runs.firstAnswerPause), key: Self.heldKey) { [weak self] in self?.endHold() }
            read(need: need)
        } else {
            onReady()
            read(need: need)
        }
        runs.updateClock()
    }

    /// Stops what only an open sheet needs. A read that nothing else wants stops. A call that does work goes on.
    public func close() {
        guard isOpen else { return }
        isOpen = false
        isInView = false
        for (key, pause) in pauses where key != Self.levelKey {
            pause.cancel()
            pauses[key] = nil
        }
        if let search = running(Self.searchKey) { stop(search) }
        editing = nil
        held = nil
        panel?.clearSelection()
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

    /// The panel closed: a sheet of parts closes and drops its values, so the next open reads again. A sheet of rows stays.
    func panelClosed() {
        if panel != nil {
            close()
            panel = nil
            answered = nil
        }
        isInView = false
        stopUnwantedRead()
    }

    /// The panel opened: an open sheet of rows is in view again and reads, by M1 and M2.
    func panelOpened() {
        if isOpen, !isInView {
            isInView = true
            read()
        }
    }

    /// Stops each read of this script, whose sheet no longer has a use for it.
    func stopReads() {
        if let read = running(Self.readKey) { stop(read) }
    }

    /// Whether something wants this script now (L3).
    var isWanted: Bool {
        isInView || runs.wants(command)
    }

    /// Stops each call, so that none changes anything, and drops all that would start a new call.
    func prepareToQuit() {
        pauses.values.forEach { $0.cancel() }
        pauses = [:]
        waitingDrops = []
        waitingKeys = []
        readsAgain = false
        calls.forEach(stop)
    }

    /// Asks the script for what it shows. A request joins the read that runs (M1). A `panel` or a `sheet` moment uses an answer
    /// younger than 5 seconds (M2). A file with no `read` gets its click instead.
    public func read(selecting run: String? = nil, need: ReadNeed = .moment, reason: ReadReason? = nil) {
        let reason = reason ?? (need == .change ? .change : isOpen ? .sheet : .panel)
        if let run { selecting = run }
        guard list.search == .local else { return ask() }
        if running(Self.readKey) != nil {
            if need == .change { readsAgain = true }
            return
        }
        if need == .moment, let answered, runs.now().timeIntervalSince(answered) < Self.answerAge {
            selectKept()
            showRunning()
            return
        }
        startRead(reports: need != .clock, reason: reason)
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

    /// Whether a read of this script runs.
    var isReading: Bool {
        running(Self.readKey) != nil
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
        state = SpotState(title: state.title, subtitle: state.subtitle, on: action.arguments == ["on"], size: state.size)
        work(action, key: Self.cardKey, undo: before)
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
            work(.level(state.level ?? 0), key: Self.levelKey)
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

    /// Runs an action. A second press of a running action stops its call.
    public func run(_ action: CommandAction, item: SpotItem?) {
        press(.action(action, item: item))
    }

    /// Asks for the form of an action: the call of that action, with empty stdin. Returns nil when a person pressed it again.
    public func form(_ action: CommandAction, item: SpotItem?) async throws -> ItemForm? {
        let call = SpotAction.action(action, item: item)
        guard let text = try await text(of: call, input: nil) else { return nil }
        guard let form = ItemForm(output: PluginOutput(text: text)) else { throw PluginError.badForm }
        return form
    }

    /// Gives a filled form to the script, and reads again with the row it saved selected. Returns false when a person
    /// pressed it again.
    public func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft) async throws -> Bool {
        let call = SpotAction.action(action, item: item)
        guard let text = try await text(of: call, input: draft.text) else { return false }
        let run = text.trimmingCharacters(in: .whitespacesAndNewlines)
        read(selecting: run.isEmpty ? nil : run, need: .change)
        return true
    }

    /// Stops a running call: it gets the terminate signal and 2 seconds, and it changes nothing.
    public func stop(_ call: ScriptCall) {
        call.stop()
        calls.removeAll { $0 === call }
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

    private func start(
        _ action: SpotAction,
        key: String,
        input: String?,
        limit: TimeInterval?,
        variables: [String: String] = [:],
        onFrame: @escaping @MainActor (ScriptCall, String) async -> Void,
        onEnd: @escaping @MainActor (ScriptCall.End) async -> Void
    ) {
        let call = runs.call(command, action, key: key, input: input, limit: limit, variables: variables, onFrame: onFrame) { [weak self] call, end in
            self?.calls.removeAll { $0 === call }
            await onEnd(end)
            self?.startWaitingDrop()
            self?.startWaitingKey()
        }
        calls.append(call)
        if call.doesWork {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.workPause))
                self?.workPauses += 1
            }
        }
    }

    private func startRead(reports: Bool, reason: ReadReason) {
        list.beginLoading()
        let action = command.read == nil ? command.click : SpotAction.read
        let generation = panel?.generation
        var isFirst = true
        start(
            action,
            key: Self.readKey,
            input: isOpen ? panel?.values : nil,
            limit: action == .read ? runs.readLimit : nil,
            variables: action == .read ? reason.variables : [:],
            onFrame: { [weak self] call, text in
                guard let self else { return }
                if isFirst {
                    isFirst = false
                    await takeAnswer(PluginOutput(text: text), frame: text, generation: generation)
                } else {
                    takeLaterFrame(PluginOutput(text: text), frame: text)
                }
                if !isWanted, !call.isStopped { stop(call) }
            },
            onEnd: { [weak self] end in
                guard let self else { return }
                switch end {
                case .stopped:
                    list.stopLoading()
                    guard !isFirst else {
                        waiter = nil
                        readsAgain = false
                        return
                    }
                case .ended:
                    if isFirst { await takeAnswer(PluginOutput(text: ""), frame: "", generation: generation) }
                case .failed(let error):
                    answered = nil
                    list.loadFailed()
                    reading.markStale()
                    answerArrived()
                    if reports { fail(error) }
                }
                if readsAgain {
                    readsAgain = false
                    read(need: .change)
                }
            }
        )
    }

    /// Takes the first frame of a read, or the silence of a read that ended by itself: all that the spot shows.
    private func takeAnswer(_ lines: PluginOutput, frame: String, generation: Int?) async {
        answered = runs.now()
        lastFrame = frame
        lastAnswer = lines
        report(toastOf: lines)
        command = command.taking(lines)
        takeState(lines)
        takeValue(lines)
        list.take(search: lines.search)
        list.take(perLine: lines.perLine ?? 1)
        takePanel(lines, generation: generation)
        list.replace(lines.items)
        selectKept()
        if list.search == .script, !list.query.isEmpty { ask() }
        showRunning()
        answerArrived()
        onReport(.frame(frame))
        await prepare(lines.items)
        if command.hasSpot, !lines.errors.isEmpty {
            onReport(.failure("\(command.name) sent \(lines.errors.count) items Openspot cannot read."))
        }
    }

    /// Takes a later frame of a read that keeps printing.
    private func takeLaterFrame(_ lines: PluginOutput, frame: String) {
        lastFrame = frame
        report(toastOf: lines)
        takeValue(lines)
        if lines.summary != nil { takeState(lines) }
        if !lines.items.isEmpty { list.replace(lines.items) }
        if isOpen { panel?.merge(lines, keeping: editing) }
        onReport(.frame(frame))
    }

    private func takeState(_ lines: PluginOutput?) {
        guard let lines, var next = try? command.state(of: lines) else {
            if lines == nil { state = command.headerState }
            return
        }
        if running(Self.levelKey) != nil || pauses[Self.levelKey] != nil, let level = state.level { next = next.withLevel(level) }
        state = next
    }

    private func takeValue(_ lines: PluginOutput) {
        if let value = MetricValue(output: lines) {
            reading.take(value)
        } else {
            reading.markStale()
        }
    }

    private func report(toastOf lines: PluginOutput) {
        if let toast = lines.toast { onReport(.toast(toast)) }
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

    /// Lets a sheet that held its motion move.
    private func endHold() {
        pauses[Self.heldKey]?.cancel()
        pauses[Self.heldKey] = nil
        let work = held
        held = nil
        work?()
    }

    /// Shows the parts a script printed. An answer that a newer change outdated does not show.
    private func takePanel(_ lines: PluginOutput, generation: Int?) {
        if panel == nil {
            panel = SheetParts(output: lines)
        } else {
            panel?.take(lines, answering: generation ?? panel?.generation ?? 0)
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
        var hasAnswer = false
        start(
            .items(query: query),
            key: Self.searchKey,
            input: nil,
            limit: runs.readLimit,
            variables: ReadReason.search.variables,
            onFrame: { [weak self] call, text in
                hasAnswer = true
                let lines = PluginOutput(text: text)
                await self?.prepare(lines.items)
                guard !call.isStopped else { return }
                self?.takeSearch(lines, frame: text, query: query)
            },
            onEnd: { [weak self] end in
                guard let self else { return }
                switch end {
                case .stopped:
                    break
                case .ended:
                    if !hasAnswer { takeSearch(PluginOutput(text: ""), frame: "", query: query) }
                case .failed(let error):
                    list.stopWaiting(for: query)
                    answerArrived()
                    if error as? PluginError != .timedOut { fail(error) }
                }
            }
        )
    }

    private func takeSearch(_ lines: PluginOutput, frame: String, query: String) {
        lastFrame = frame
        lastAnswer = lines
        command = command.taking(lines)
        list.take(search: lines.search)
        list.take(perLine: lines.perLine ?? 1)
        list.answer(lines.items, to: query)
        answerArrived()
    }

    /// Runs one change of a sheet of parts. Only the newest answer replaces the sheet.
    private func change(_ action: SpotAction, key: String, generation: Int, keeping: String?, closes: Bool) {
        guard let values = panel?.values else { return }
        work(action, key: key, input: values, generation: generation, keeping: keeping, readsAfter: !closes)
    }

    /// Starts or stops the call of a person's press.
    private func press(_ action: SpotAction) {
        let key = Self.key(call: action)
        if let running = running(key) { return pressAgain(running) }
        work(action, key: key)
    }

    /// Runs a call that does work. It has no time limit, and it goes on with the sheet and the panel closed. A stopped call
    /// changes nothing. After one that ended with no state to show, the script is read once (M4).
    private func work(
        _ action: SpotAction,
        key: String,
        input: String? = nil,
        generation: Int? = nil,
        keeping: String? = nil,
        readsAfter: Bool = true,
        undo: SpotState? = nil
    ) {
        answered = nil
        var showedState = false
        start(
            action,
            key: key,
            input: input,
            limit: nil,
            onFrame: { [weak self] _, text in
                guard let self else { return }
                let lines = PluginOutput(text: text)
                lastFrame = text
                report(toastOf: lines)
                if let block = lines.summary { state = state.taking(block) }
                showedState = showedState || !lines.parts.isEmpty || lines.summary?.flag("on") != nil || lines.summary?.number("level") != nil
                if isOpen { panel?.merge(lines, answering: generation, keeping: keeping ?? editing) }
                onReport(.frame(text))
            },
            onEnd: { [weak self] end in
                guard let self else { return }
                switch end {
                case .stopped:
                    if let undo { state = undo }
                case .ended:
                    answered = nil
                    if !showedState, readsAfter { readOnce() }
                case .failed(let error):
                    answered = nil
                    if let undo { state = undo }
                    fail(error)
                    if readsAfter { readOnce() }
                }
            }
        )
    }

    private func readOnce() {
        if command.read != nil { read(need: .change) }
    }

    /// Runs a call to its end, and returns all that it printed, or nil when it was stopped or pressed again. A second press
    /// stops it.
    private func text(of action: SpotAction, input: String?) async throws -> String? {
        let key = Self.key(call: action)
        if let running = running(key) {
            pressAgain(running)
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            var text = ""
            start(
                action,
                key: key,
                input: input,
                limit: nil,
                onFrame: { [weak self] _, frame in
                    text += frame
                    self?.report(toastOf: PluginOutput(text: frame))
                },
                onEnd: { end in
                    switch end {
                    case .stopped: continuation.resume(returning: nil)
                    case .ended: continuation.resume(returning: text)
                    case .failed(let error): continuation.resume(throwing: error)
                    }
                }
            )
        }
    }

    /// Tells the person about a failed call: the script's own message when it gave one, or else what Openspot saw.
    private func fail(_ error: Error) {
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
