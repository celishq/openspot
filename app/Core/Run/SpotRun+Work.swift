import Foundation

extension SpotRun {
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

    public func press(_ part: SpotPart) {
        let key = Self.key(part: part.id)
        if let running = running(key) { return pressAgain(running) }
        guard let generation = panel?.advance() else { return }
        editing = nil
        change(.press(part.id), key: key, generation: generation, keeping: nil, closes: part.closes)
    }

    public var isCardRunning: Bool {
        running(Self.cardKey) != nil
    }

    public var work: [ScriptCall] {
        _ = workPauses
        let time = runs.now()
        return workCalls.filter { time.timeIntervalSince($0.started) >= Self.workPause }
    }

    public var cardWork: ScriptCall? {
        shown(Self.cardKey)
    }

    public func work(of part: SpotPart) -> ScriptCall? {
        shown(Self.key(part: part.id))
    }

    public func work(of row: ActionMenu.Row, item: SpotItem?) -> ScriptCall? {
        if let action = row.action { return shown(Self.key(call: .action(action, item: item))) }
        return shown(item.map { Self.key(call: .item($0)) } ?? Self.cardKey)
    }

    public var shownState: SpotState {
        guard let call = work.first else { return state }
        return state.showing(title: call.title, detail: call.detail)
    }

    public func pressCard() {
        if let running = running(Self.cardKey) { return pressAgain(running) }
        if spot.kind == .launch, spot.takesDrops { return onReport(.chooseFiles) }
        guard spot.kind == .toggle else { return work(spot.click, key: Self.cardKey) }
        let before = state
        let action = SpotAction.toggle(state)
        state = state.switched(on: !(state.on ?? false))
        work(action, key: Self.cardKey, as: Work(undo: before))
    }

    public func setCardPart(_ id: String, to value: String?) {
        guard let value else { return work(.press(id), key: Self.key(part: id)) }
        state = state.setting(value, of: id)
        work(.set(id, to: value), key: Self.key(part: id))
    }

    @discardableResult
    public func drop(_ paths: [String]) -> Bool {
        guard spot.accepts(paths) else { return false }
        waitingFiles.append(.drop(paths: paths))
        startWaitingFiles()
        return true
    }

    public func dragged(_ items: [SpotItem]) {
        guard !items.isEmpty else { return }
        waitingFiles.append(.drag(runs: items.map(\.run)))
        startWaitingFiles()
    }

    func startWaitingFiles() {
        guard !waitingFiles.isEmpty, !calls.contains(where: \.doesWork) else { return }
        work(waitingFiles.removeFirst(), key: Self.cardKey)
    }

    public func pressKey(_ call: String) {
        waitingKeys.append(call)
        startWaitingKey()
    }

    func startWaitingKey() {
        guard !waitingKeys.isEmpty, running(Self.globalKey) == nil else { return }
        work(.press(waitingKeys.removeFirst()), key: Self.globalKey)
    }

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

    public func pick(_ item: SpotItem) {
        if let to = item.to {
            guard let other = runs.sheets[to] else { return fail(SpotError.failed(1, "\(spot.name) hands this row to `\(to)`, which is not on. Turn it on, then try again.")) }
            return other.press(.item(item), input: item.fields)
        }
        guard list.search == .script, !list.query.isEmpty else { return press(.item(item)) }
        press(.item(item), input: TextBlock(fields: [.init(key: "search", value: list.query)]).text)
    }

    public func set(_ item: SpotItem, to value: String) {
        press(.set(item.run, to: value))
    }

    public func run(_ action: CommandAction, item: SpotItem?) {
        press(.action(action, item: item))
    }

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

    public func stop(_ call: ScriptCall) {
        call.stop()
        forget(call)
        link.stop(call)
    }

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

    func after(_ pause: Duration, key: String, _ work: @escaping () -> Void) {
        pauses[key]?.cancel()
        pauses[key] = Task { [weak self] in
            try? await Task.sleep(for: pause)
            guard !Task.isCancelled else { return }
            self?.pauses[key] = nil
            work()
        }
    }

    private func change(_ action: SpotAction, key: String, generation: Int, keeping: String?, closes: Bool) {
        guard let values = panel?.values else { return }
        work(action, key: key, input: values, as: Work(generation: generation, keeping: keeping, readsAfter: !closes))
    }

    private func press(_ action: SpotAction, input: String? = nil) {
        let key = Self.key(call: action)
        if let running = running(key) { return pressAgain(running) }
        work(action, key: key, input: input)
    }

    private func work(_ action: SpotAction, key: String, input: String? = nil, as work: Work = Work()) {
        answered = nil
        link.send(Call(action: action, key: key, input: input, purpose: .work(work)))
    }
}
