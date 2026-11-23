import Foundation

extension SpotRun {
    public func set(_ part: SpotPart, to value: String) {
        guard let generation = panel?.set(value, of: part.id) else { return }
        if part.isEditable { editing = part.id }
        let key = Self.key(part: part.id)
        if let older = running(key) { stop(older) }
        let keeping = part.isEditable ? part.id : nil
        let send: () -> Void = { [weak self] in self?.change(part.id, to: value, key: key, generation: generation, keeping: keeping, closes: false, waits: false) }
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
        change(part.id, to: nil, key: key, generation: generation, keeping: nil, closes: part.closes, waits: spot.takesHandlers)
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

    public var sheetState: SpotState {
        page.route == nil ? shownState.showing(title: page.title, detail: nil) : shownState
    }

    public func pressCard() {
        if let running = running(Self.cardKey) { return pressAgain(running) }
        guard spot.kind == .toggle else { return act(Message(spot.click), key: Self.cardKey) }
        let before = state
        let message = Self.toggling(state)
        state = state.switched(on: !(state.on ?? false))
        act(message, key: Self.cardKey, as: Act(undo: before))
    }

    public func setCardPart(_ id: String, to value: String?) {
        guard let value else { return act(Message(.press(id)), key: Self.key(part: id)) }
        state = state.setting(value, of: id)
        act(Self.setting(id, to: value), key: Self.key(part: id))
    }

    @discardableResult
    public func drop(_ paths: [String], files: FileKinds? = nil) -> Bool {
        guard files.map(spot.accepts) ?? spot.accepts(paths) else { return false }
        waitingFiles.append(Handler.drop.message(paths))
        startWaitingFiles()
        return true
    }

    public func dragged(_ items: [SpotItem]) {
        guard !items.isEmpty else { return }
        waitingFiles.append(Handler.drag.message(items.map(\.run)))
        startWaitingFiles()
    }

    func startWaitingFiles() {
        guard !waitingFiles.isEmpty, !calls.contains(where: \.isAct) else { return }
        act(waitingFiles.removeFirst(), key: Self.cardKey)
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

    func trigger(_ message: Message, key: String) {
        send(Call(message: message, key: key, purpose: .act(Act(showsAfter: false)), isPressed: false))
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
            act(Self.level(state.level ?? 0, of: state.control ?? ""), key: Self.levelKey)
        }
    }

    public func pick(_ item: SpotItem, closes: Bool = false) {
        press(picking(item), closes: closes)
    }

    public func answer(toPick item: SpotItem, closes: Bool = false) async -> CallAnswer {
        await answer(toPress: picking(item), closes: closes)
    }

    private func picking(_ item: SpotItem) -> Message {
        guard item.isToggle else { return Handler.press.message([item.run], then: item.carried) }
        var message = Self.setting(item.run, to: item.isOn ? "false" : "true")
        message.inputs += item.carried
        return message
    }

    private func acting(_ action: CommandAction, item: SpotItem?) -> Message {
        let inputs = item.map { [TextBlock.Field(key: Self.itemInput, value: $0.run)] + $0.carried } ?? []
        return Message(.press(CommandAction.command(of: action) ?? action.id), inputs: inputs)
    }

    public func answer(to action: CommandAction, item: SpotItem?, closes: Bool = false) async -> CallAnswer {
        await answer(toPress: acting(action, item: item), closes: closes)
    }

    private func answer(toPress message: Message, closes: Bool = false) async -> CallAnswer {
        let key = Self.key(of: message)
        if let running = running(key) {
            pressAgain(running)
            return .stopped
        }
        answered = nil
        let answer = try? await withCheckedThrowingContinuation { waiting in
            let first = FirstFrame(waiting)
            if !send(Call(message: message, key: key, purpose: .act(Act(first: first, started: runs.now(), closes: closes)))) { first.end(.stopped) }
        }
        return answer ?? .stopped
    }

    public func set(_ item: SpotItem, to value: String) {
        press(Self.setting(item.run, to: value))
    }

    public func run(_ action: CommandAction, item: SpotItem?, ended: (() -> Void)? = nil) {
        press(acting(action, item: item), ended: ended)
    }

    public func change(_ action: CommandAction) async throws -> CallAnswer {
        let call = SpotWords.action(action, item: nil)
        guard let key = freeKey(call), let output = try await answer(to: acting(action, item: nil), key: key) else { return .stopped }
        if let form = Self.form(in: output) { return .form(form) }
        show(need: .change)
        return .done
    }

    public func launch(_ action: CommandAction, search: SearchQuery, onCard: Bool = false) async throws -> CallAnswer {
        let call = SpotWords.action(action, item: nil)
        guard let key = freeKey(call, onCard: onCard) else { return .stopped }
        answered = nil
        let typed = typedAction(of: call)
        if let typed, let input = typed.textInput {
            let values = search.text.isEmpty ? [:] : [input.name: search.text]
            let lacks = typed.inputs.contains { $0.isRequired && $0.defaultValue == nil && values[$0.name] == nil }
            if lacks, let form = ItemForm(output: Frame(text: typed.form(with: values, title: action.title))) { return .form(form) }
        }
        let message = CommandAction.word(of: action).map { Handler.command.message([$0], [search.text]) }
            ?? typed?.textInput.map { Message(call, inputs: [.init(key: $0.name, value: search.text)]) }
            ?? Message(call)
        return try await withCheckedThrowingContinuation { waiting in
            let first = FirstFrame(waiting)
            if !send(Call(message: message, key: key, purpose: .act(Act(first: first, started: runs.now())))) { first.end(.stopped) }
        }
    }

    public func type(_ text: String) {
        typed = text
        if list.holdsItems { search(text) }
        show(need: .change)
    }

    public func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft) async throws -> CallAnswer {
        let word = CommandAction.word(of: action)
        let call = word == nil ? SpotWords.action(action, item: item) : .press(Handler.command.name)
        guard let key = freeKey(call) else { return .stopped }
        let message = word.map { Handler.command.message([$0], then: draft.inputs) }
            ?? Message(.press(CommandAction.command(of: action) ?? action.id), inputs: draft.inputs + (item.map { [TextBlock.Field(key: Self.itemInput, value: $0.run)] } ?? []))
        guard !script.keepsState else {
            act(message, key: key)
            return .done
        }
        guard let output = try await answer(to: message, key: key) else { return .stopped }
        if let form = Self.form(in: output) {
            if draft.isMultiple { show(need: .change) }
            return .form(form)
        }
        show(selecting: output.select, need: .change)
        return .done
    }

    private func freeKey(_ call: SpotWords, onCard: Bool = false) -> String? {
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

    private static let valueInput = "value"
    static let itemInput = "item"

    private static func key(part id: String) -> String {
        "part:\(id)"
    }

    private static func key(call words: SpotWords) -> String {
        "call:\(words.arguments.joined(separator: "\n"))"
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

    private func change(_ id: String, to value: String?, key: String, generation: Int, keeping: String?, closes: Bool, waits: Bool) {
        guard let inputs = panel?.inputs else { return }
        let message = Message(.press(id), inputs: inputs + (value.map { [TextBlock.Field(key: Self.valueInput, value: $0)] } ?? []))
        act(message, key: key, as: Act(generation: generation, keeping: keeping, showsAfter: !closes, closes: closes && waits))
    }

    private static func setting(_ id: String, to value: String) -> Message {
        Message(.press(id), inputs: [.init(key: valueInput, value: value)])
    }

    static func toggling(_ state: SpotState) -> Message {
        setting(state.control ?? "", to: (state.on ?? false) ? "false" : "true")
    }

    static func level(_ value: Double, of control: String) -> Message {
        setting(control, to: String(Int(value.rounded())))
    }

    private static func key(of message: Message) -> String {
        let item = message.inputs.first { $0.key == itemInput }.map { [$0.value] } ?? []
        return key(call: SpotWords(arguments: message.words.arguments + item))
    }

    private func press(_ message: Message, ended: (() -> Void)? = nil, closes: Bool = false) {
        let key = Self.key(of: message)
        if let running = running(key) { return pressAgain(running) }
        act(message, key: key, as: Act(ended: ended, closes: closes))
    }

    private func act(_ message: Message, key: String, as act: Act = Act()) {
        answered = nil
        var act = act
        act.started = runs.now()
        send(Call(message: message, key: key, purpose: .act(act)))
    }
}

extension SpotRun {
    public func call(_ action: String, inputs: [TextBlock.Field] = []) async throws -> [TextBlock.Field] {
        let message = Message(.press(action), inputs: inputs)
        guard let output = try await answer(to: message, key: "call:\(action)") else { return [] }
        return output.outputs
    }
}
