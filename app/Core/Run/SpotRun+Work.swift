import Foundation

/// The calls of work of a run: the presses and the values of parts, cards, rows, keys and forms, and their stops.
extension SpotRun {
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

    /// Whether a call of the card runs.
    public var isCardRunning: Bool {
        running(Self.cardKey) != nil
    }

    /// The calls that show as running work: each one that does work and has run for 1 second, the oldest first (L6). A new
    /// one shows by itself, because `workPauses` changes when its second has passed.
    public var work: [ScriptCall] {
        _ = workPauses
        let time = runs.now()
        return workCalls.filter { time.timeIntervalSince($0.started) >= Self.workPause }
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
        if spot.kind == .launch, spot.takesDrops { return onReport(.chooseFiles) }
        guard spot.kind == .toggle else { return work(spot.click, key: Self.cardKey) }
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
        guard spot.accepts(paths) else { return false }
        waitingFiles.append(.drop(paths: paths))
        startWaitingFiles()
        return true
    }

    /// Tells the script of the rows that a drag took out to another app (O2).
    public func dragged(_ items: [SpotItem]) {
        guard !items.isEmpty else { return }
        waitingFiles.append(.drag(runs: items.map(\.run)))
        startWaitingFiles()
    }

    func startWaitingFiles() {
        guard !waitingFiles.isEmpty, !calls.contains(where: \.doesWork) else { return }
        work(waitingFiles.removeFirst(), key: Self.cardKey)
    }

    /// Takes a press of a key that a person assigned to a command. Presses run one at a time and in order, and none stops a call.
    public func pressKey(_ call: String) {
        waitingKeys.append(call)
        startWaitingKey()
    }

    func startWaitingKey() {
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

    /// Runs a pick of a row. A second pick of a running row stops its call. In a list that the script searches, stdin holds
    /// the text of the search, so that a pick that comes before the read of the last text still gets it. A row with `to` goes
    /// to that spot instead, with the row on stdin (J1).
    public func pick(_ item: SpotItem) {
        if let to = item.to {
            guard let other = runs.sheets[to] else { return fail(SpotError.failed(1, "\(spot.name) hands this row to `\(to)`, which is not on. Turn it on, then try again.")) }
            return other.press(.item(item), input: item.fields)
        }
        guard list.search == .script, !list.query.isEmpty else { return press(.item(item)) }
        press(.item(item), input: TextBlock(fields: [.init(key: "search", value: list.query)]).text)
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
        let key = Self.key(call: call)
        if let running = running(key) {
            pressAgain(running)
            return nil
        }
        guard let text = try await link.form(call, key: key) else { return nil }
        guard let form = ItemForm(output: SpotOutput(text: text)) else { throw SpotError.badForm }
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
        if let form = ItemForm(output: SpotOutput(text: text)), !form.fields.isEmpty { return .form(form) }
        read(need: .change)
        return .done
    }

    /// Gives a filled form to the script, and reads again with the row it saved selected. A script that answers with a form
    /// asks again, and after a pick in a choice of several, which the script keeps, the spot reads again too. Returns nil
    /// when a person pressed it again.
    public func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft) async throws -> FormAnswer? {
        let call = SpotAction.action(action, item: item)
        let key = Self.key(call: call)
        if let running = running(key) {
            pressAgain(running)
            return nil
        }
        guard let text = try await link.submit(call, key: key, values: draft.text) else { return nil }
        guard !link.keepsState else { return .done }
        if let form = ItemForm(output: SpotOutput(text: text)), !form.fields.isEmpty {
            if draft.isMultiple { read(need: .change) }
            return .form(form)
        }
        let run = text.trimmingCharacters(in: .whitespacesAndNewlines)
        read(selecting: run.isEmpty ? nil : run, need: .change)
        return .done
    }

    /// Stops a running call: it gets the terminate signal and 2 seconds, and it changes nothing. A call of a staying script
    /// gets a `stop` block instead.
    public func stop(_ call: ScriptCall) {
        call.stop()
        forget(call)
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

    func running(_ key: String) -> ScriptCall? {
        calls.first { $0.key == key }
    }

    /// Runs the work after the pause. A new request with the same key replaces it.
    func after(_ pause: Duration, key: String, _ work: @escaping () -> Void) {
        pauses[key]?.cancel()
        pauses[key] = Task { [weak self] in
            try? await Task.sleep(for: pause)
            guard !Task.isCancelled else { return }
            self?.pauses[key] = nil
            work()
        }
    }

    /// Runs one change of a sheet of parts. Only the newest answer replaces the sheet.
    private func change(_ action: SpotAction, key: String, generation: Int, keeping: String?, closes: Bool) {
        guard let values = panel?.values else { return }
        work(action, key: key, input: values, as: Work(generation: generation, keeping: keeping, readsAfter: !closes))
    }

    /// Starts or stops the call of a person's press.
    private func press(_ action: SpotAction, input: String? = nil) {
        let key = Self.key(call: action)
        if let running = running(key) { return pressAgain(running) }
        work(action, key: key, input: input)
    }

    /// Runs a call that does work. It has no time limit, and it goes on with the sheet and the panel closed. A stopped call
    /// changes nothing. After one that ended with no picture shown, a script that runs once is read once (M4).
    private func work(_ action: SpotAction, key: String, input: String? = nil, as work: Work = Work()) {
        answered = nil
        link.send(Call(action: action, key: key, input: input, purpose: .work(work)))
    }
}
