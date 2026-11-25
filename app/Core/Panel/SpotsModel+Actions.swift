import Foundation

extension SpotsModel {
    var target: Target? {
        if let entry = openEntry {
            return (entry, openSheet?.selectedItem)
        }
        guard content != .attachment, let entry = selectedEntry else { return nil }
        if let item = entry.item, let list = self.entry(entry.spot.id) { return (list, item) }
        return (entry, nil)
    }

    func openSheet(on key: ActionKey) -> Bool {
        guard let id = spot(openedBy: key), openSheetID == nil || place(ofSheet: id) == .window else { return false }
        endEditing(moving: false)
        pushFirst(id, moving: true)
        return true
    }

    func spot(openedBy key: ActionKey) -> String? {
        let chosen = arrangement.spot(openedBy: key, over: defaultArrangement).flatMap { id in entry(id) == nil ? nil : id }
        return chosen ?? (key == Self.settingsKey ? settingsSpot : nil)
    }

    static let settingsKey = ActionKey(name: ",", isCommand: true)

    static func editsText(_ key: ActionKey) -> Bool {
        key.isCommand && !key.isShift && ["backspace", "a", "c", "v", "x", "z"].contains(key.name)
    }

    func handleRowsPanelKey(_ key: ActionKey, _ panel: SheetParts) -> Bool {
        if let part = panel.selectedPart { return handleFocusKey(key, part) }
        if key == ActionKey(name: "up"), openItems?.isOnFirstLine != false { return openSheet?.leaveRows(upward: true) == true }
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
        if part.closesOnSet, isShown { host.dismiss() }
    }

    public func pressPart(_ part: SpotPart) {
        openSheet?.press(part)
        if part.closes, isShown, openSheet?.spot.takesHandlers != true { host.dismiss() }
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
            let asks = (try? target.entry.spot.action(action.callName))?.lacksInput == true || action.confirm != nil
            if asks, place == .window {
                toast(.failure("\(action.title) asks with a form or a second press, which a window does not show yet."))
            } else if asks {
                press(target.entry.id)
            } else if target.entry.spot.takesHandlers, let sheet = sheets[target.entry.id] {
                Task { [weak self] in
                    guard case .form = await sheet.answer(to: action, item: target.item), let self else { return }
                    if place == .window { toast(.failure("\(action.title) asks with a form, which a window does not show yet.")) } else { press(target.entry.id) }
                }
            } else {
                sheets[target.entry.id]?.run(action, item: target.item)
            }
        } else if action == .open || action == .history {
            presentSheet(of: target.entry.id)
        } else if let typed = try? target.entry.spot.action(action.callName), typed.lacksInput {
            show(.form(typed.itemForm(title: action.title)), of: action, on: target, prefill: "")
        } else if case .command(let command) = action.kind {
            if isShown { host.dismiss() }
            sheets[target.entry.id]?.pressKey(command)
        } else if action.after == .stay {
            perform(action, on: target)
        } else if target.entry.spot.takesHandlers {
            perform(action, on: target, closes: true)
        } else if let item = target.item {
            pick(item, of: target.entry, action: action)
        } else {
            if isShown { host.dismiss() }
            perform(action, on: target)
        }
    }

    func perform(_ action: CommandAction, on target: Target, closes: Bool = false) {
        guard target.entry.spot.takesHandlers, let sheet = sheets[target.entry.id] else {
            sheets[target.entry.id]?.run(action, item: target.item)
            return
        }
        Task { [weak self] in
            guard case .form(let form) = await sheet.answer(to: action, item: target.item, closes: closes), let self, isShown else { return }
            show(.form(form), of: action, on: target, prefill: "")
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
                toast(.failure("\(action.title) failed. \(Self.reason(error))"))
            }
        }
    }

    func show(_ answer: CallAnswer, of action: CommandAction, on target: Target, prefill: String) {
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
            let action = CommandAction.secret(key, title: field.title)
            self.form = FormSession(draft: FormDraft(form: form), entry: entry, action: action, item: nil, openedSheet: true)
            return true
        }
        if let field = entry.spot.settings.first(where: { $0.id == key && !$0.options.isEmpty }) {
            pushFirst(id, moving: true)
            let options = field.options.map { SpotPart.Option(id: $0, title: $0) }
            let form = ItemForm(title: field.title, fields: [ItemForm.Field(name: key, label: field.title, type: .choice, value: runs.settings[id]?[key], options: options)])
            let action = CommandAction.option(key, title: field.title)
            self.form = FormSession(draft: FormDraft(form: form), entry: entry, action: action, item: nil, openedSheet: true)
            return true
        }
        let action = CommandAction(id: key, title: "Change \(key)", scope: .spot, after: .close)
        ask(action, on: (entry, nil), whileShown: true) { try await sheet.change(action) }
        return true
    }

    public func chooseFormOption(_ item: SpotItem) {
        asOnePress {
            form?.draft.choose(item.run)
            submitForm()
        }
    }

    public func setFormValue(_ text: String, for name: String) {
        asOnePress {
            form?.draft.set(text, for: name)
        }
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
            toast(.failure("Enter a value for \(missing.label)."))
            return
        }
        send(form, form.draft)
    }

    private func keepOption(_ key: String, _ form: FormSession, _ draft: FormDraft) {
        let spot = form.entry.id
        do {
            let next = try files.config.change { $0.set(setting: key, of: spot, to: draft.values[key]) }
            self.form = nil
            closeSheet(moving: true)
            configChanged(.value(spot: spot, caller: nil), to: next)
        } catch {
            toast(.failure("\(form.action.title) failed. \(Self.reason(error))"))
        }
    }

    public func keep(secret value: String, key: String, of spot: String) async -> String? {
        if value.count < SecretStore.shortest {
            return "Openspot didn't keep this secret, because it is shorter than \(SecretStore.shortest) characters. Type the whole value."
        }
        if let failure = await Self.keep(value, key: key, of: spot, in: files.secrets) { return failure }
        configChanged(.value(spot: spot, caller: nil), to: kept)
        return nil
    }

    private func keepSecret(_ key: String, _ form: FormSession, _ draft: FormDraft) {
        let spot = form.entry.id
        let value = draft.values[key] ?? ""
        if !value.isEmpty, value.count < SecretStore.shortest {
            return toast(.failure("Openspot didn't keep this secret, because it is shorter than \(SecretStore.shortest) characters. Type the whole value."))
        }
        let secrets = files.secrets
        Task {
            if let failure = await Self.keep(value.isEmpty ? nil : value, key: key, of: spot, in: secrets) {
                return toast(.failure("\(form.action.title) failed. \(failure)"))
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
        if case .secret(let key) = form.action.kind { return keepSecret(key, form, draft) }
        if case .option(let key) = form.action.kind { return keepOption(key, form, draft) }
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
                toast(.failure("\(form.action.title) failed. \(Self.reason(error))"))
            }
        }
    }
}
