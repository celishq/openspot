import Foundation

extension SpotsModel {
    func takeMode() {
        let next: PanelMode = recording != nil ? .recording : isMenuOpen ? .menu : isEditing ? .edit : form != nil ? .form : openSheetID != nil ? .sheet : .grid
        if next != mode { mode = next }
    }

    public func handleKey(_ key: ActionKey) -> Bool {
        spoilCommand(by: key)
        return take(key, in: keyRows(of: mode))
    }

    public func handleSearchKey(_ key: ActionKey) -> Bool {
        guard mode == .sheet || mode == .grid, showsSearch, openParts?.selectedPart == nil else { return false }
        return take(key, in: searchRows)
    }

    private func take(_ key: ActionKey, in rows: [KeyRow]) -> Bool {
        asOnePress {
            for row in rows where row.takes(key) {
                if let handled = row.act(key) { return handled }
            }
            return false
        }
    }

    public func pressHint(_ label: String) {
        asOnePress {
            guard let key = ActionKey(label: label) else { return }
            if !handleKey(key) { _ = handleSearchKey(key) }
        }
    }

    func keyRows(of mode: PanelMode) -> [KeyRow] {
        switch mode {
        case .recording: recordingRows
        case .menu: menuRows
        case .edit: editRows
        case .form: formRows
        case .sheet, .grid: spotRows
        }
    }

    private var recordingRows: [KeyRow] {
        let cancel = KeyRow("escape", command: nil, shift: nil, words: "Cancel") { [self] _ in
            let field = recordsField ? recording : nil
            stopRecording()
            if let field { focusAfterRecording(field) }
            return true
        }
        return [cancel]
    }

    private var menuRows: [KeyRow] {
        let close: @MainActor (ActionKey) -> Bool? = { [self] _ in
            closeMenu()
            return true
        }
        let move = { [self] (step: Int) -> @MainActor (ActionKey) -> Bool? in
            { [self] _ in
                menu?.move(by: step)
                return true
            }
        }
        return [
            KeyRow("k", command: true, act: close),
            KeyRow("escape", act: close),
            KeyRow("up", act: move(-1)),
            KeyRow("down", act: move(1)),
            KeyRow("return") { [self] _ in
                pressMenu()
                return true
            },
            KeyRow("right") { [self] _ in
                guard menu?.selectedRow?.children.isEmpty == false else { return nil }
                _ = menu?.enterSelected()
                return true
            },
            KeyRow("left") { [self] _ in
                guard menu?.parent != nil else { return nil }
                _ = menu?.back()
                return true
            },
            .any { [self] key in
                let types = menu?.isSearchable == true && !key.isCommand
                guard !types, let action = menu?.rows.compactMap(\.action).first(where: { $0.key == key }) else { return !types }
                menu?.select(action)
                pressMenu()
                return true
            },
        ]
    }

    private var editRows: [KeyRow] {
        let always = { (work: @escaping @MainActor () -> Void) -> @MainActor (ActionKey) -> Bool? in
            { _ in
                work()
                return true
            }
        }
        let shifted = { [self] (name: String, dx: Int, dy: Int, glyph: String?) in
            KeyRow(name, command: nil, shift: true, glyph: glyph, words: glyph.map { _ in "Move" }, act: always { self.moveSelectedSpot(dx: dx, dy: dy) })
        }
        let plain = { [self] (name: String, dx: Int, dy: Int) in
            KeyRow(name, command: nil, shift: false, act: always { self.moveSelection(dx: dx, dy: dy) })
        }
        let held = !isArranging
        let rows: [KeyRow?] = [
            .any { [self] key in
                guard gesture != nil || carry != nil else { return nil }
                if key.name == "escape" {
                    cancelDrag()
                    cancelResize()
                    cancelPin()
                }
                return true
            },
            .any { [self] key in openSheet(on: key) ? true : nil },
            held ? KeyRow("s", command: nil, shift: nil, words: "Size", act: always { [self] in stepSelectedSize() }) : nil,
            shifted("left", -1, 0, "⇧ Arrows"),
            shifted("up", 0, -1, nil),
            shifted("right", 1, 0, nil),
            shifted("down", 0, 1, nil),
            KeyRow("escape", command: nil, shift: nil, words: "Done", act: always { [self] in endEditing() }),
            held ? plain("left", -1, 0) : nil,
            held ? plain("right", 1, 0) : nil,
            plain("up", 0, -1),
            plain("down", 0, 1),
            held ? .any { _ in true } : nil,
        ]
        return rows.compactMap { $0 }
    }

    var formRows: [KeyRow] {
        guard let form else { return [] }
        let isList = form.draft.choices != nil
        let isMultiple = form.draft.isMultiple
        let move = { [self] (step: Int) -> @MainActor (ActionKey) -> Bool? in
            { [self] _ in
                guard isList else { return nil }
                self.form?.draft.move(by: step)
                return true
            }
        }
        return [
            KeyRow("return", words: isList ? (isMultiple ? "Select" : "Save") : nil) { [self] _ in
                guard isList else { return nil }
                submitForm()
                return true
            },
            KeyRow("return", command: true, words: isList ? nil : "Save") { [self] _ in
                submitForm()
                return true
            },
            KeyRow("a", command: true, shift: true, words: isMultiple ? "Select all" : nil) { [self] _ in
                guard isMultiple else { return nil }
                if let all = form.draft.selectingAll() { send(form, all) }
                return true
            },
            KeyRow("up", act: move(-1)),
            KeyRow("down", act: move(1)),
            KeyRow("escape", words: isMultiple ? "Done" : "Cancel") { [self] _ in
                if form.draft.choices?.query.isEmpty == false { self.form?.draft.search("") } else { cancelForm() }
                return true
            },
        ]
    }

    var escapeWords: String {
        flow.behind == nil ? "Close" : "Back"
    }

    var escapeRow: KeyRow {
        KeyRow("escape", words: escapeWords) { [self] _ in
            if let target, let action = target.entry.spot.frameActions(for: target.item).first(where: { $0.key == ActionKey(name: "escape") }) {
                run(action, on: target)
            } else if !stepBack() {
                host.dismiss()
            }
            return true
        }
    }

    var settingsRow: KeyRow {
        let shows = target.map { openSheetID == nil && $0.item == nil && hasSettings($0.entry) } ?? false
        return KeyRow("return", command: true, words: shows ? "Settings" : nil) { [self] _ in
            openSourceSettings() || openSelectedSettings() ? true : nil
        }
    }

    private var spotRows: [KeyRow] {
        var rows: [KeyRow] = [
            .any { [self] key in openSheetID == nil ? nil : handleFlowKey(key) },
            settingsRow,
        ]
        let parts = openParts
        let partKey = KeyRow.any { [self] key in
            guard let part = parts?.parts.first(where: { $0.key == key }) else { return nil }
            pressPart(part)
            return true
        }
        if let parts, !parts.showsRows {
            let scroll = { [self] (step: Int) -> @MainActor (ActionKey) -> Bool? in
                { [self] _ in
                    guard parts.scrollsByArrows else { return nil }
                    openSheet?.scrollPanel(by: step)
                    return true
                }
            }
            return rows + [
                partKey,
                KeyRow("k", command: true) { [self] _ in
                    guard let target else { return nil }
                    openMenu(on: target)
                    return menu != nil
                },
                KeyRow("escape") { [self] _ in
                    if !stepBack() { host.dismiss() }
                    return true
                },
                KeyRow("up", act: scroll(-1)),
                KeyRow("down", act: scroll(1)),
                .any { [self] key in
                    guard let part = parts.selectedPart else { return false }
                    return handleFocusKey(key, part)
                },
            ]
        }
        if let parts {
            rows.append(.any { [self] key in handleRowsPanelKey(key, parts) ? true : nil })
            rows.append(partKey)
        }
        rows += [
            KeyRow("tab", shift: nil) { [self] key in takeTab(back: key.isShift) },
            KeyRow("escape") { [self] _ in
                guard attachments.isOn, openSheetID == nil else { return nil }
                leaveAttachment()
                return true
            },
            escapeRow,
            KeyRow("k", command: true) { [self] _ in
                guard let target else { return nil }
                guard actionMenu(on: target)?.holdsMore == true else { return false }
                openMenu(on: target)
                return menu != nil
            },
            .any { [self] key in target.flatMap { runAction(with: key, on: $0) } },
            .any { [self] key in openSheet(on: key) ? true : nil },
        ]
        return rows
    }

    var confirmRow: KeyRow {
        KeyRow("return", shift: nil, words: waitingWords) { [self] _ in runConfirmed() ? true : nil }
    }

    private var searchRows: [KeyRow] {
        [
            confirmRow,
            KeyRow("return", shift: nil) { [self] _ in
                runSelected()
                return true
            },
            KeyRow("down", command: nil, shift: nil) { [self] key in moveLine(by: 1, toEdge: key.isCommand) },
            KeyRow("up", command: nil, shift: nil) { [self] key in moveLine(by: -1, toEdge: key.isCommand) },
            KeyRow("left", command: nil, shift: nil) { [self] _ in moveAlong(by: -1) },
            KeyRow("right", command: nil, shift: nil) { [self] _ in moveAlong(by: 1) },
        ]
    }

    private func runAction(with key: ActionKey, on target: Target) -> Bool? {
        let typesKey = !searchText.isEmpty && Self.editsText(key)
        var none = HookAnswers()
        if !typesKey, !target.entry.spot.frameActions(for: target.item).contains(where: { $0.key == key }),
           let offer = offered(on: target, answers: &none, asks: false).first(where: { $0.action.key == key }) {
            if offer.action.confirm != nil {
                openMenu(on: target)
                menu?.select(offer.action)
                pressMenu()
            } else {
                run(offer.action, offeredBy: offer.owner, on: target)
            }
            return true
        }
        let quiet = typesKey ? [] : extras(on: target)
        guard let action = (target.entry.spot.frameActions(for: target.item) + quiet).first(where: { $0.key == key }) else { return nil }
        if action.confirm != nil {
            openMenu(on: target)
            menu?.select(action)
            pressMenu()
        } else {
            run(action, on: target)
        }
        return true
    }

    private func moveLine(by step: Int, toEdge: Bool) -> Bool {
        if openSheetID == nil {
            moveSelection(dx: 0, dy: step)
        } else if toEdge {
            moveItemToEdge(last: step > 0)
        } else {
            moveItemLine(by: step)
        }
        return true
    }

    private func moveAlong(by step: Int) -> Bool? {
        if openSheetID != nil {
            guard (openItems?.perLine ?? 1) > 1 else { return false }
            moveItem(by: step)
        } else if !query.isEmpty {
            return false
        } else if selectedIsSlider {
            adjustSelected(by: Double(5 * step))
        } else {
            moveSelection(dx: step, dy: 0)
        }
        return true
    }
}
