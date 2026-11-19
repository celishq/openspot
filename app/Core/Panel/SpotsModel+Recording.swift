import Foundation

extension SpotsModel {
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
}
