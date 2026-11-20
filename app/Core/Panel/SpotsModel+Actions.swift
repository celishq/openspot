import Foundation

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

    static func editsText(_ key: ActionKey) -> Bool {
        key.isCommand && !key.isShift && ["backspace", "a", "c", "v", "x", "z"].contains(key.name)
    }

    func handleRowsPanelKey(_ key: ActionKey, _ panel: SheetParts) -> Bool {
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

    @discardableResult
    public func openEdit(of entry: Entry) -> Bool {
        let spot = entry.spot
        guard entry.item == nil, spot.fault == nil, spot.host == nil, !spot.isBuiltIn,
              let sheet = runs.editSheet(of: spot, isOwn: !folder.isCore(spot))
        else { return false }
        pushFirst(sheet.spot.id, moving: true)
        return true
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
            presentSheet(of: target.entry.id)
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
        ask(action, on: target, prefill: prefill, waits: true) { [sheets] in
            try await sheets[target.entry.id]?.form(action, item: target.item, search: prefill).map(CallAnswer.form)
        }
    }

    func ask(_ action: CommandAction, on target: Target, prefill: String = "", whileShown: Bool = false, waits: Bool = false, _ call: @escaping @MainActor () async throws -> CallAnswer?) {
        let ask = UUID()
        pendingAsk = ask
        let wait = waits ? startWaiting(action.openWords) : nil
        Task {
            defer { if let wait { endWaiting(wait) } }
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
            self.form = FormSession(draft: FormDraft(form: form, prefill: prefill), entry: target.entry, action: action, item: target.item, openedSheet: opensSheet, tookSearch: !prefill.isEmpty)
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
        if let field = entry.spot.settings.first(where: { $0.id == key && !$0.options.isEmpty }) {
            pushFirst(id, moving: true)
            let options = field.options.map { SpotPart.Option(id: $0, title: $0) }
            let form = ItemForm(title: field.title, fields: [ItemForm.Field(name: key, label: field.title, type: .choice, value: runs.settings[id]?[key], options: options)])
            let action = CommandAction(id: Self.optionPrefix + key, title: "Change \(field.title)", scope: .spot, after: .stay)
            self.form = FormSession(draft: FormDraft(form: form), entry: entry, action: action, item: nil, openedSheet: true)
            return true
        }
        let action = CommandAction(id: key, title: "Change \(key)", scope: .spot, after: .close)
        ask(action, on: (entry, nil), whileShown: true) { try await sheet.change(action) }
        return true
    }

    public func chooseFormOption(_ item: SpotItem) {
        guard form?.draft.picking != nil else {
            form?.draft.choose(item.run)
            return submitForm()
        }
        takeFormPick(item.run)
    }

    func takeFormPick(_ id: String? = nil) {
        guard var draft = form?.draft, let field = draft.pickedField else { return }
        if let id { draft.choose(id) }
        if let id = draft.choices?.selectedItem?.run, field.picks == nil, field.options.first(where: { $0.id == id })?.sends == true {
            draft.endPicking()
            if draft != form?.draft { form?.draft = draft }
            return sendFormOption(id, of: field.name)
        }
        _ = draft.takePick()
        if draft != form?.draft { form?.draft = draft }
    }

    public func sendFormOption(_ id: String, of name: String) {
        guard let form else { return }
        if let missing = form.draft.missing {
            host.notify("Enter a value for \(missing.label).")
            return
        }
        var draft = form.draft
        draft.set(id, for: name)
        send(form, draft)
    }

    public func setFormValue(_ text: String, for name: String) {
        form?.draft.set(text, for: name)
    }

    public func focusFormField(_ name: String?) {
        guard let draft = form?.draft, draft.focusing(name) != draft.focus else { return }
        form?.draft.focus(on: name)
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
    private static let optionPrefix = "openspot.option."

    private func keepOption(_ form: FormSession, _ draft: FormDraft) {
        let key = String(form.action.id.dropFirst(Self.optionPrefix.count))
        let spot = form.entry.id
        do {
            let next = try files.config.change { $0.set(setting: key, of: spot, to: draft.values[key]) }
            self.form = nil
            closeSheet(moving: true)
            configChanged(.value(spot: spot, caller: nil), to: next)
        } catch {
            host.notify("\(form.action.title) failed. \(Self.reason(error))")
        }
    }

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
        if form.action.id.hasPrefix(Self.optionPrefix) { return keepOption(form, draft) }
        let wait = startWaiting(form.action.sendWords)
        Task {
            defer { endWaiting(wait) }
            do {
                switch try await sheets[form.entry.id]?.submit(form.action, item: form.item, draft: draft) {
                case .done? where self.form?.id == form.id:
                    self.form = nil
                    if form.tookSearch, openSheet?.query.isEmpty == false { openSheet?.search("") }
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

extension SpotsModel {
    static let waitPause: Duration = .milliseconds(300)

    func startWaiting(_ words: String) -> UUID {
        let id = UUID()
        waits[id] = words
        Task { [weak self] in
            try? await Task.sleep(for: Self.waitPause, tolerance: .milliseconds(50))
            guard let self, let words = self.waits[id] else { return }
            self.shownWait = id
            let hint = HintWords(words)
            if self.waiting != hint { self.waiting = hint }
        }
        return id
    }

    func endWaiting(_ id: UUID) {
        waits[id] = nil
        guard shownWait == id else { return }
        shownWait = nil
        if waiting != nil { waiting = nil }
    }
}
