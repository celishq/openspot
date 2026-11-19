import Foundation
import Observation

extension SpotsModel {
    var target: Target? {
        if let entry = openEntry {
            return (entry, openSheet?.selectedItem)
        }
        guard let entry = selectedEntry else { return nil }
        if let item = entry.item, let list = self.entry(entry.spot.id) { return (list, item) }
        return (entry, nil)
    }

    func openSheet(on key: ActionKey) -> Bool {
        guard openSheetID == nil, let id = spot(openedBy: key) else { return false }
        endEditing(moving: false)
        pushFirst(id, moving: true)
        return true
    }

    func spot(openedBy key: ActionKey) -> String? {
        arrangement.spot(openedBy: key, over: defaultArrangement).flatMap { id in entry(id) == nil ? nil : id }
    }

    public static func editsText(_ key: ActionKey) -> Bool {
        key.isCommand && !key.isShift && ["backspace", "a", "c", "v", "x", "z"].contains(key.name)
    }

    func handleRowsPanelKey(_ key: ActionKey, _ panel: SheetParts) -> Bool {
        if key == ActionKey(name: "down", isCommand: true), let main = panel.parts.first(where: { $0.look == .strong && $0.isPressable }), panel.selectedPart?.id != main.id {
            openSheet?.landRows()
            _ = openSheet?.leaveRows()
            openSheet?.focusPart(main.id)
            return true
        }
        if let part = panel.selectedPart { return handleFocusKey(key, part) }
        openSheet?.landRows()
        guard key == ActionKey(name: "down"), openItems?.isOnLastLine != false else { return false }
        return openSheet?.leaveRows() == true
    }

    func handleFocusKey(_ key: ActionKey, _ part: SpotPart) -> Bool {
        switch key {
        case ActionKey(name: "up"), ActionKey(name: "down"):
            let moved = openSheet?.movePartLine(by: key.name == "up" ? -1 : 1) ?? false
            return moved || !part.isEditable
        case ActionKey(name: "left"), ActionKey(name: "right"):
            guard !part.isEditable else { return false }
            let step = key.name == "left" ? -1 : 1
            if case .slider(let level, let low, let high) = part.control {
                let next = min(max(level + Double(step) * max((high - low) / 20, 1), low), high)
                setPart(part, to: String(Int(next.rounded())))
            } else {
                openSheet?.movePart(by: step)
            }
        case ActionKey(name: "return"), ActionKey(name: " "):
            guard !part.isEditable else { return false }
            useSelected(part)
        default:
            return false
        }
        return true
    }

    private func useSelected(_ part: SpotPart) {
        switch part.control {
        case .shortcut: toggleRecording(part)
        case .toggle(let on): setPart(part, to: on ? "false" : "true")
        case .menu: openSheet?.openMenu(of: part)
        case .slider: break
        default: pressPart(part)
        }
    }

    public func focusPart(_ part: SpotPart) {
        openSheet?.focusPart(part.id)
    }

    public func setPart(_ part: SpotPart, to value: String) {
        openSheet?.set(part, to: value)
    }

    public func pressPart(_ part: SpotPart) {
        openSheet?.press(part)
        if part.closes, isShown { host.dismiss() }
    }

    public func toggleRecording(_ part: SpotPart) {
        toggleRecording(id: part.id)
    }

    func recordAskedField() {
        takeKeyField()
        guard isShown, !isWarming, recording == nil, let id = openSheetID, let run = sheets[id],
              let part = openParts?.parts.first(where: \.asksToRecord) else { return }
        let answer = "\(id)#\(run.partsAnswers)"
        guard askedAnswer != answer else { return }
        askedAnswer = answer
        toggleRecording(part)
    }

    func takeKeyField() {
        takeEntryKey()
        guard recording == nil, let parts = openParts, parts.selected == nil, let field = keyField, field.control != .shortcut(""),
              parts.selectedPart?.id == field.id else { return }
        focusAfterRecording(field.id)
    }

    func focusAfterRecording(_ field: String) {
        guard let parts = openParts else { return }
        let order = parts.focusOrder
        let isEmpty = parts.parts.contains { $0.id == field && $0.control == .shortcut("") }
        guard !isEmpty, let index = order.firstIndex(where: { $0.id == field }), order.indices.contains(index + 1) else {
            openSheet?.focusPart(field)
            return
        }
        openSheet?.focusPart(order[index + 1].id)
    }

    public func toggleRecording(id: String) {
        if recording == id {
            stopRecording()
        } else {
            recording = id
            keys.start()
            if openParts?.parts.contains(where: { $0.id == id }) == true { openSheet?.focusPart(id) }
            takeEntryKey()
            readTakenKeys()
        }
    }

    private func readTakenKeys() {
        let systemKeys = files.systemKeys
        let config = files.config
        let names = Dictionary(entries.map { ($0.id, $0.spot.name) }, uniquingKeysWith: { first, _ in first })
        Task.detached { [weak self] in
            var taken = systemKeys.read()
            for key in config.read().keys {
                guard case .key(let shortcut) = key.trigger else { continue }
                taken.append(TakenKey(shortcut: shortcut, use: "opens \(names[key.spot] ?? key.spot)"))
            }
            await self?.keys.take(taken)
        }
    }

    public func stopRecording() {
        guard recording != nil else { return }
        recording = nil
        takeEntryKey()
    }

    var holdsKeyField: Bool {
        keyField != nil
    }

    private var keyField: SpotPart? {
        openParts?.parts.first { if case .shortcut = $0.control { true } else { false } }
    }

    public var takesEveryKey: Bool {
        isShown && recording == nil && keyField != nil
    }

    func takeEntryKey() {
        let off = isShown && (recording != nil || holdsKeyField)
        guard off != entryKeyIsOff else { return }
        entryKeyIsOff = off
        host.setEntryKey(on: !off)
    }

    var recordsField: Bool {
        openItems?.shown.contains { $0.run == recording } != true && openParts?.parts.contains { $0.id == recording } == true
    }

    public func record(code: UInt32, modifiers: Shortcut.Modifiers) {
        let part = openParts?.parts.first { $0.id == recording }
        let item = openItems?.shown.first { $0.run == recording }
        let isField = recordsField
        if isField { keys.press(code) }
        guard let shortcut = Shortcut(code: code, modifiers: modifiers) else {
            guard isField else { return host.notify("Hold cmd, ctrl or option with a letter, a digit, a sign, an arrow, space, return or tab.") }
            keys.refuse(code: code, modifiers: modifiers)
            return
        }
        if takesShake, shortcut.isAppKey {
            host.notify("\(KeyRecording.appWords(shortcut)), or tap one key such as `⌥`.")
            return
        }
        if isField, shortcut.isAppKey {
            keys.refuseAppKey(shortcut)
            return
        }
        if item != nil {
            if keys.use(of: shortcut) != nil { host.notify(keys.words(for: shortcut)) }
        } else if isField {
            keys.check(shortcut)
        }
        stopRecording()
        if let part {
            setPart(part, to: shortcut.text)
            focusAfterRecording(part.id)
        }
        if let item, let entry = openEntry { give(shortcut.text, to: item, of: entry) }
    }

    private func give(_ key: String, to item: SpotItem, of entry: Entry) {
        sheets[entry.id]?.set(item, to: key)
        guard !entry.spot.holdsSettings, !item.staysOnPick else { return }
        closingPick = (item, entry)
        if isShown {
            host.dismiss()
        } else {
            finishPick()
        }
    }

    public var takesShake: Bool {
        guard let recording else { return false }
        return openItems?.shown.first { $0.run == recording }?.takesShake ?? false
    }

    public var recordingWords: String {
        takesShake ? "Press keys or shake" : "Press keys"
    }

    public func recordShake() {
        recordTrigger(.shake)
    }

    public func recordTap(_ modifier: Shortcut.Modifiers) {
        recordTrigger(.tap(modifier))
    }

    private func recordTrigger(_ trigger: Trigger) {
        guard takesShake, let recording, let entry = openEntry, let item = openItems?.shown.first(where: { $0.run == recording }) else { return }
        stopRecording()
        give(trigger.text, to: item, of: entry)
    }

    public func dragMenu(to point: CGPoint) {
        if let row = menuRow(at: point) { self.point(at: .menuRow(row)) }
    }

    public func releaseMenu(at point: CGPoint) {
        if let row = menuRow(at: point) { pressMenu(row: row) }
    }

    private func menuRow(at point: CGPoint) -> Int? {
        guard let menu, let frame = menuFrame else { return nil }
        return frame.row(at: point, of: menu)
    }

    public var menu: ActionMenu? {
        get { menuSession?.phase == .closing ? nil : menuSession?.menu }
        set {
            guard let newValue, menu != nil else { return }
            menuSession?.menu = newValue
            placeSubmenu()
        }
    }

    func placeSubmenu() {
        var row: CGRect?
        if let menu, let submenu = menu.submenu, let frame = menuFrame, menuSession?.phase != .closing {
            row = frame.rowRect(submenu.parent, of: menu)
        }
        guard row != menuSession?.submenuRow else { return }
        menuSession?.submenuRow = row
        if let row, let menu, let frame = menuFrame {
            host.showSubmenu(beside: row, of: frame.rect(of: menu))
        } else {
            host.hideSubmenu()
        }
    }

    public func pointSubmenu(row: Int) {
        menu?.pointSubmenu(at: row)
    }

    public func pressSubmenu(row: Int) {
        menu?.pointSubmenu(at: row)
        pressMenu()
    }

    public var menuTarget: Target? {
        menu == nil ? nil : menuSession?.target
    }

    public func placeMenu(_ frame: ActionMenuFrame) {
        guard menu != nil, frame != menuFrame else { return }
        menuFrame = frame
        if menuSession?.phase != .opening { fitMenuContent() }
        placeSubmenu()
    }

    public func menuItemAtRest(_ item: CGRect) -> CGRect {
        guard isMenuOpen, openSheetID == nil, let size = placements.first(where: { $0.index == selected })?.size else { return item }
        let width = SpotTokens.width(columns: size.columns) * MotionTokens.focusedScale
        let height = SpotTokens.height(rows: size.rows) * MotionTokens.focusedScale
        return CGRect(x: item.midX - width / 2, y: item.midY - height / 2, width: width, height: height)
    }

    private func fitMenuContent() {
        let height = menuFrame.map { $0.rect.maxY + SpotTokens.halo + SpotTokens.hintBlock } ?? 0
        if height != menuContentHeight { menuContentHeight = height }
    }

    public func searchMenu(_ text: String) {
        menu?.search(text)
    }

    public func openMenu(at point: CGPoint) {
        let origin = gridOrigin
        guard openSheetID == nil, !isEditing, let id = card(at: CGPoint(x: point.x - origin.x, y: point.y - origin.y)), let index = visible.firstIndex(where: { $0.id == id }) else { return }
        selected = index
        if let target { openMenu(on: target) }
    }

    func openMenu(on target: Target) {
        var answers = HookAnswers()
        menuSession = actionMenu(on: target, answers: &answers, asks: true).map { ActionMenuSession(menu: $0, target: target, answers: answers) }
        host.nextFrame { [weak self] in
            guard let self, menuSession?.phase == .opening else { return }
            change(.sheet(isOpen: true), {
                self.menuSession?.phase = .open
                self.fitMenuContent()
            }, completion: { [weak self] in
                if self?.menuSession?.phase == .open { self?.menuSession?.phase = .settled }
            })
        }
    }

    func menuOpens(on target: Target) -> Bool {
        guard let menu = actionMenu(on: target) else { return false }
        return menu.holdsMore || (openParts?.drawsKeys == true && !menu.rows.isEmpty)
    }

    func actionMenu(on target: Target) -> ActionMenu? {
        var none = HookAnswers()
        return actionMenu(on: target, answers: &none, asks: false)
    }

    private func actionMenu(on target: Target, answers: inout HookAnswers, asks: Bool) -> ActionMenu? {
        let isOpenList = openSheetID == target.entry.id
        return ActionMenu(
            spot: target.entry.spot,
            item: target.item,
            showsOpen: !isOpenList || target.item != nil,
            extras: extras(on: target),
            offered: offered(on: target, answers: &answers, asks: asks)
        )
    }

    func extras(on target: Target) -> [CommandAction] {
        guard openSheetID == nil, target.item == nil else { return [] }
        let spot = target.entry.spot
        let opens: [CommandAction] = spot.pressRuns && target.entry.kind.opensSheet ? [.open] : []
        let history: [CommandAction] = spot.keepsHistory ? [.history] : []
        let commands = spot.opensToKeys || spot.soleCommand != nil ? [] : spot.offers.map(CommandAction.command)
        return opens + history + commands
    }

    @discardableResult
    public func openEdit(of entry: Entry) -> Bool {
        let spot = entry.spot
        guard entry.item == nil, spot.fault == nil, spot.host == nil, !spot.isBuiltIn,
              let sheet = runs.editSheet(of: spot, isOwn: !folder.isCore(spot))
        else { return false }
        pushFirst(sheet.spot.id, moving: true)
        return true
    }

    func offered(on target: Target, answers: inout HookAnswers, asks: Bool) -> [OfferedAction] {
        guard openSheetID == nil, target.item == nil, let origin = origin(of: target.entry.spot) else { return [] }
        let word = OfferedAction.originWords.first { $0.value == origin }?.key ?? ""
        var shown: [OfferedAction] = []
        let deadline = DispatchTime.now() + runs.frameWait
        for spot in sheets.values.lazy.map(\.spot).filter({ !$0.offeredActions.isEmpty }).sorted(by: { $0.id < $1.id }) {
            var hidden: [String] = []
            for offer in spot.offeredActions {
                let id = offer.action.id
                func ask(_ hook: ActionHook) -> String? {
                    answer(hook, of: offer, by: spot, on: target, origin: word, until: deadline, answers: &answers, asks: asks)
                }
                let shows = offer.fits(origin) && !hidden.contains { id.hasPrefix($0 + ".") } && (offer.hooks[.when] == nil || ask(.when)?.isEmpty == false)
                if shows { shown.append(ask(.hotkey).map(offer.labeled) ?? offer) } else { hidden.append(id) }
            }
        }
        return shown
    }

    private func answer(
        _ hook: ActionHook, of offer: OfferedAction, by spot: Spot, on target: Target, origin: String, until deadline: DispatchTime, answers: inout HookAnswers, asks: Bool
    ) -> String? {
        guard let function = offer.hooks[hook] else { return nil }
        if let text = answers.text(hook, of: offer, in: spot.id) { return text }
        guard asks else { return nil }
        let card = target.entry.id
        let now = runs.answer(function, of: spot, card: card, origin: origin, until: deadline) { [weak self] text in
            guard !text.isEmpty, let self, let session = menuSession, session.phase != .closing, session.target.entry.id == card, session.menu.parent == nil,
                  session.answers.text(hook, of: offer, in: spot.id) == nil else { return }
            var answers = session.answers
            answers.keep(text, for: hook, of: offer, in: spot.id)
            remake(session, answers: &answers)
        }
        if let now { answers.keep(now, for: hook, of: offer, in: spot.id) }
        return now
    }

    private func remake(_ session: ActionMenuSession, answers: inout HookAnswers) {
        guard var menu = actionMenu(on: session.target, answers: &answers, asks: false) else { return }
        menu.search(session.menu.query)
        if let action = session.menu.selectedRow?.action { menu.select(action) }
        menuSession?.answers = answers
        menuSession?.menu = menu
    }

    func origin(of spot: Spot) -> SpotOrigin? {
        if spot.fault != nil { return .mine }
        guard spot.host == nil else { return nil }
        if spot.isBuiltIn { return .builtIn }
        return folder.isCore(spot) ? .core : .mine
    }

    public func run(_ action: CommandAction, offeredBy owner: String, on target: Target) {
        if action.after == .close {
            closeMenu()
            if isShown { host.dismiss() }
        }
        sheets[owner]?.run(action, item: SpotItem(title: target.entry.state.title, run: target.entry.id)) { [weak self] in
            guard let self, flow.current == nil || transition.id != nil else { return }
            closeMenu()
        }
    }

    public func followHint() {
        guard !followsHint else { return }
        followsHint = true
        takeHint()
    }

    private func takeHint() {
        hintTakes += 1
        let words = HintWords(withObservationTracking { hint } onChange: { [weak self] in
            Task { @MainActor in self?.takeHint() }
        })
        let motion: PanelMotion? = isEditing || hintIsForEdit || fieldDrop != nil ? .fade : nil
        hintIsForEdit = isEditing
        if openSheetID == nil, spotDrop == nil {
            if words != gridHint { change(motion, { gridHint = words }) }
        } else {
            takeSheetHint(words, motion: motion)
        }
    }

    func takeSheetHint(_ words: HintWords, motion: PanelMotion? = nil) {
        if words != sheetHint { change(motion, { sheetHint = words }) }
    }

    var selectedGlyphTitle: String? {
        guard openSheetID == nil, let entry = selectedEntry, entry.kind != .widget,
              placements.first(where: { $0.index == selected })?.size == .small
        else { return nil }
        return entry.state.title
    }

    public func closeMenu(keepsFoot: Bool = false) {
        guard menu != nil else { return }
        if menuSession?.submenuRow != nil {
            menuSession?.submenuRow = nil
            host.hideSubmenu()
        }
        change(.sheet(isOpen: false), {
            menuSession?.phase = .closing
            if !keepsFoot, menuContentHeight != 0 { menuContentHeight = 0 }
        }, completion: { [weak self] in
            if self?.menuSession?.phase == .closing { self?.menuSession = nil }
        })
    }

    public func pressMenu(row: Int) {
        guard let menu, menu.shown.indices.contains(row) else { return }
        guard menu.shown[row].children.isEmpty else { return point(at: .menuRow(row)) }
        _ = self.menu?.back()
        self.menu?.move(by: row - menu.selected)
        pressMenu()
    }

    func pressMenu() {
        let isRunning = menu?.selectedRow.map { work(of: $0) != nil } ?? false
        guard let row = menu?.press(isRunning: isRunning), let target = menuTarget else { return }
        if !isRunning, let action = row.action, action.isForm {
            openForm(action, on: target)
            return
        }
        if let action = row.action, let owner = row.owner {
            return run(action, offeredBy: owner, on: target)
        }
        closeMenu()
        if let action = row.action {
            run(action, on: target)
        } else if let item = target.item {
            pick(item, of: target.entry)
        } else {
            run(target.entry)
        }
    }

    public func run(_ action: CommandAction, on target: Target, in place: SheetPlace = .panel) {
        if place.isDetached {
            if action.isForm || action.confirm != nil, place == .window {
                host.notify("\(action.title) asks with a form or a second press, which a window does not show yet.")
            } else if action.isForm || action.confirm != nil {
                press(target.entry.id)
            } else {
                sheets[target.entry.id]?.run(action, item: target.item)
            }
        } else if action == .open || action == .history {
            presentSheet(of: target.entry.id, moving: true)
        } else if let command = CommandAction.command(of: action) {
            if isShown { host.dismiss() }
            sheets[target.entry.id]?.pressKey(command)
        } else if action.isForm {
            openForm(action, on: target)
        } else if action.after == .stay {
            sheets[target.entry.id]?.run(action, item: target.item)
        } else if let item = target.item {
            pick(item, of: target.entry, action: action)
        } else {
            if isShown { host.dismiss() }
            sheets[target.entry.id]?.run(action, item: nil)
        }
    }

    public func openForm(_ action: CommandAction, on target: Target, prefill: String = "") {
        guard place(ofSheet: target.entry.id) == .panel else {
            return host.notify("\(action.title) asks with a form, which a window does not show yet.")
        }
        ask(action, on: target, prefill: prefill) { [sheets] in
            try await sheets[target.entry.id]?.form(action, item: target.item).map(CallAnswer.form)
        }
    }

    func ask(_ action: CommandAction, on target: Target, prefill: String = "", whileShown: Bool = false, _ call: @escaping @MainActor () async throws -> CallAnswer?) {
        let ask = UUID()
        pendingAsk = ask
        Task {
            do {
                guard let answer = try await call(), pendingAsk == ask else { return }
                pendingAsk = nil
                if whileShown, !isShown, case .form = answer { return }
                show(answer, of: action, on: target, prefill: prefill)
            } catch {
                if pendingAsk == ask { pendingAsk = nil }
                closeMenu()
                host.notify("\(action.title) failed. \(Self.reason(error))")
            }
        }
    }

    private func show(_ answer: CallAnswer, of action: CommandAction, on target: Target, prefill: String) {
        let id = target.entry.id
        switch answer {
        case .form(let form):
            closeMenu()
            let opensSheet = openSheetID != id
            if opensSheet { pushFirst(id, moving: isShown) }
            self.form = FormSession(draft: FormDraft(form: form, prefill: prefill), entry: target.entry, action: action, item: target.item, openedSheet: opensSheet)
        case .shown where target.entry.spot.kind.opensSheet:
            if openSheetID != id { pushFirst(id, moving: isShown) }
        case .shown, .done:
            if action.after == .close, isShown { host.dismiss() }
        case .stopped:
            break
        }
    }

    public func changeSetting(_ key: String, of id: String) -> Bool {
        guard let entry = entry(id), let sheet = sheets[id] else { return false }
        if let field = entry.spot.settings.first(where: { $0.id == key && $0.isSecret }) {
            pushFirst(id, moving: true)
            let form = ItemForm(title: field.title, fields: [ItemForm.Field(name: key, label: field.title, type: .secret)])
            let action = CommandAction(id: Self.secretPrefix + key, title: "Change \(field.title)", scope: .spot, after: .stay)
            self.form = FormSession(draft: FormDraft(form: form), entry: entry, action: action, item: nil, openedSheet: true)
            return true
        }
        let action = CommandAction(id: key, title: "Change \(key)", scope: .spot, after: .close)
        ask(action, on: (entry, nil), whileShown: true) { try await sheet.change(action) }
        return true
    }

    public func chooseFormOption(_ item: SpotItem) {
        form?.draft.choose(item.run)
        submitForm()
    }

    public func setFormValue(_ text: String, for name: String) {
        form?.draft.set(text, for: name)
    }

    public func cancelForm() {
        pendingAsk = nil
        guard let form else { return }
        self.form = nil
        if form.openedSheet {
            closeSheet(moving: true)
        }
    }

    public func submitForm() {
        guard let form else { return }
        if let missing = form.draft.missing {
            host.notify("Enter a value for \(missing.label).")
            return
        }
        send(form, form.draft)
    }

    private static let secretPrefix = "openspot.secret."

    private func keepSecret(_ form: FormSession, _ draft: FormDraft) {
        let key = String(form.action.id.dropFirst(Self.secretPrefix.count))
        let spot = form.entry.id
        let value = draft.values[key] ?? ""
        if !value.isEmpty, value.count < SecretStore.shortest {
            return host.notify("Openspot didn't keep this secret, because it is shorter than \(SecretStore.shortest) characters. Type the whole value.")
        }
        let secrets = files.secrets
        Task {
            if let failure = await Self.keep(value.isEmpty ? nil : value, key: key, of: spot, in: secrets) {
                return host.notify("\(form.action.title) failed. \(failure)")
            }
            guard self.form?.id == form.id else { return }
            self.form = nil
            closeSheet(moving: true)
            configChanged(.value(spot: spot, caller: nil), to: kept)
        }
    }

    @concurrent
    private nonisolated static func keep(_ value: String?, key: String, of spot: String, in secrets: SecretStore) async -> String? {
        do {
            try secrets.keep(value, key: key, of: spot)
            return nil
        } catch {
            return reason(error)
        }
    }

    func send(_ form: FormSession, _ draft: FormDraft) {
        if form.action.id.hasPrefix(Self.secretPrefix) { return keepSecret(form, draft) }
        Task {
            do {
                switch try await sheets[form.entry.id]?.submit(form.action, item: form.item, draft: draft) {
                case .done? where self.form?.id == form.id:
                    self.form = nil
                    if form.action.after == .close, isShown { host.dismiss() }
                case .form(let next)? where self.form?.id == form.id:
                    let kept = FormDraft(form: next, after: self.form?.draft ?? draft)
                    self.form?.draft = kept
                default:
                    break
                }
            } catch {
                host.notify("\(form.action.title) failed. \(Self.reason(error))")
            }
        }
    }
}
