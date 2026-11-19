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

    public var cardAct: ScriptCall? {
        shown(Self.cardKey)
    }

    public func act(of part: SpotPart) -> ScriptCall? {
        shown(Self.key(part: part.id))
    }

    public func act(of row: ActionMenu.Row, item: SpotItem?) -> ScriptCall? {
        if let action = row.action { return shown(Self.key(call: .action(action, item: item))) }
        return shown(item.map { Self.key(call: .item($0)) } ?? Self.cardKey)
    }

    public var shownState: SpotState {
        guard let call = acts.first else { return state }
        return state.showing(title: call.title, detail: call.detail)
    }

    public func pressCard() {
        if let running = running(Self.cardKey) { return pressAgain(running) }
        guard spot.kind == .toggle else { return act(Message(spot.click), key: Self.cardKey) }
        let before = state
        let action = SpotAction.toggle(state)
        state = state.switched(on: !(state.on ?? false))
        act(Message(action), key: Self.cardKey, as: Act(undo: before))
    }

    public func setCardPart(_ id: String, to value: String?) {
        guard let value else { return act(Message(.press(id)), key: Self.key(part: id)) }
        state = state.setting(value, of: id)
        act(Message(.set(id, to: value)), key: Self.key(part: id))
    }

    @discardableResult
    public func drop(_ paths: [String], files: FileKinds? = nil) -> Bool {
        guard files.map(spot.accepts) ?? spot.accepts(paths) else { return false }
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
        guard !waitingFiles.isEmpty, !calls.contains(where: \.isAct) else { return }
        act(Message(waitingFiles.removeFirst()), key: Self.cardKey)
    }

    public func pressKey(_ call: String) {
        let held = script.keepsState ? calls.count { $0.key == Self.globalKey } : 0
        if waitingKeys.count + held < Self.waitingLimit {
            waitingKeys.append(call)
        } else if held > 0 {
            onReport(.toast("\(spot.name) is still busy with \(Self.waitingLimit) presses, so Openspot dropped this one. Wait for one to end, then press again."))
        }
        startWaitingKey()
    }

    func startWaitingKey() {
        while !waitingKeys.isEmpty, script.keepsState || running(Self.globalKey) == nil {
            act(Message(.press(waitingKeys.removeFirst())), key: Self.globalKey)
        }
    }

    public func setLevel(_ value: Double) {
        let next = state.withLevel(value)
        guard next.level != state.level else { return }
        state = next
        if let older = running(Self.levelKey) { stop(older) }
        after(Self.sliderPause, key: Self.levelKey) { [weak self] in
            guard let self else { return }
            act(Message(.level(state.level ?? 0, of: state.control ?? "")), key: Self.levelKey)
        }
    }

    public func pick(_ item: SpotItem) {
        press(Message(.item(item), item: item.fields, search: list.search == .script && !list.query.isEmpty ? list.query : nil))
    }

    public func set(_ item: SpotItem, to value: String) {
        press(Message(.set(item.run, to: value)))
    }

    public func run(_ action: CommandAction, item: SpotItem?, ended: (() -> Void)? = nil) {
        press(Message(.action(action, item: item), item: item?.fields ?? []), ended: ended)
    }

    public func form(_ action: CommandAction, item: SpotItem?) async throws -> ItemForm? {
        let call = SpotAction.action(action, item: item)
        guard let key = freeKey(call), let output = try await answer(to: Message(call), key: key) else { return nil }
        guard let form = ItemForm(output: output) else { throw SpotError.badForm }
        return form
    }

    public func change(_ action: CommandAction) async throws -> CallAnswer {
        let call = SpotAction.action(action, item: nil)
        guard let key = freeKey(call), let output = try await answer(to: Message(call), key: key) else { return .stopped }
        if let form = Self.form(in: output) { return .form(form) }
        show(need: .change)
        return .done
    }

    public func launch(_ action: CommandAction, search: SearchQuery, onCard: Bool = false) async throws -> CallAnswer {
        let call = SpotAction.action(action, item: nil)
        guard let key = freeKey(call, onCard: onCard) else { return .stopped }
        answered = nil
        return try await withCheckedThrowingContinuation { waiting in
            let first = FirstFrame(waiting)
            if !send(Call(message: Message(call, search: search.text, searchForms: search.forms), key: key, purpose: .act(Act(first: first)))) { first.end(.stopped) }
        }
    }

    public func type(_ text: String) {
        typed = text
        if list.holdsItems { search(text) }
        show(need: .change)
    }

    public func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft) async throws -> CallAnswer {
        let call = SpotAction.action(action, item: item)
        guard let key = freeKey(call) else { return .stopped }
        guard !script.keepsState else {
            act(Message(call, inputs: draft.inputs), key: key)
            return .done
        }
        guard let output = try await answer(to: Message(call, inputs: draft.inputs), key: key) else { return .stopped }
        if let form = Self.form(in: output) {
            if draft.isMultiple { show(need: .change) }
            return .form(form)
        }
        show(selecting: output.select, need: .change)
        return .done
    }

    private func freeKey(_ call: SpotAction, onCard: Bool = false) -> String? {
        let key = onCard ? Self.cardKey : Self.key(call: call)
        guard let running = running(key) else { return key }
        stopPressed(running)
        return nil
    }

    private static func form(in output: Frame) -> ItemForm? {
        ItemForm(output: output).flatMap { $0.fields.isEmpty ? nil : $0 }
    }

    public func stop(_ call: ScriptCall) {
        call.stop()
        forget(call)
        link.stop(call)
    }

    private func pressAgain(_ call: ScriptCall) {
        guard script.keepsState else { return stopPressed(call) }
        guard runs.now().timeIntervalSince(call.started) >= Self.pressPause else { return }
        let heard = call.heard
        call.halt()
        after(.seconds(runs.stopPause), key: "stop:\(call.key)") { [weak self] in
            guard let self, call.heard == heard, calls.contains(where: { $0 === call }) else { return }
            stop(call)
        }
    }

    private func stopPressed(_ call: ScriptCall) {
        if runs.now().timeIntervalSince(call.started) >= Self.pressPause { stop(call) }
    }

    private static func key(part id: String) -> String {
        "part:\(id)"
    }

    private static func key(call action: SpotAction) -> String {
        "call:\(action.arguments.joined(separator: "\n"))"
    }

    private func shown(_ key: String) -> ScriptCall? {
        acts.first { $0.key == key }
    }

    func running(_ key: String) -> ScriptCall? {
        calls.first { $0.key == key }
    }

    func after(_ pause: Duration, key: String, _ work: @escaping () -> Void) {
        pauses[key]?.cancel()
        pauses[key] = Task { [weak self, sleep = runs.clock.sleep] in
            try? await sleep(pause, pause / 10)
            guard !Task.isCancelled else { return }
            self?.pauses[key] = nil
            work()
        }
    }

    private func change(_ action: SpotAction, key: String, generation: Int, keeping: String?, closes: Bool) {
        guard let inputs = panel?.inputs else { return }
        act(Message(action, inputs: inputs), key: key, as: Act(generation: generation, keeping: keeping, showsAfter: !closes))
    }

    private func press(_ message: Message, ended: (() -> Void)? = nil) {
        let key = Self.key(call: message.action)
        if let running = running(key) { return pressAgain(running) }
        act(message, key: key, as: Act(ended: ended))
    }

    private func act(_ message: Message, key: String, as act: Act = Act()) {
        answered = nil
        send(Call(message: message, key: key, purpose: .act(act)))
    }
}
