import Foundation

extension SpotsModel {
    public func dragMenu(to point: CGPoint) {
        if let row = menuRow(at: point) { self.point(at: .menuRow(row)) }
    }

    public func releaseMenu(at point: CGPoint) {
        asOnePress {
            if let row = menuRow(at: point) { pressMenu(row: row) }
        }
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
        asOnePress {
            menu?.pointSubmenu(at: row)
            pressMenu()
        }
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
        asOnePress {
            menu?.search(text)
        }
    }

    public func openMenu(at point: CGPoint) {
        asOnePress {
            let origin = gridOrigin
            guard openSheetID == nil, !isEditing, let id = card(at: CGPoint(x: point.x - origin.x, y: point.y - origin.y)), let index = visible.firstIndex(where: { $0.id == id }) else { return }
            selected = index
            if let target { openMenu(on: target) }
        }
    }

    func openMenu(on target: Target) {
        var answers = HookAnswers()
        menuSession = actionMenu(on: target, answers: &answers, asks: true).map { ActionMenuSession(menu: $0, target: target, answers: answers) }
        foldMenuFoot()
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
        let history: [CommandAction] = spot.keepsHistory ? [.history] : []
        let commands = spot.opensToKeys || spot.soleCommand != nil ? [] : spot.commands.map(CommandAction.command)
        return history + commands
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
                let shows = offer.fits(origin) && !hidden.contains { id.hasPrefix($0 + ".") }
                    && (offer.when == nil || answer(of: offer, by: spot, on: target, origin: word, until: deadline, answers: &answers, asks: asks)?.isEmpty == false)
                if shows { shown.append(offer) } else { hidden.append(id) }
            }
        }
        return shown
    }

    private func answer(
        of offer: OfferedAction, by spot: Spot, on target: Target, origin: String, until deadline: DispatchTime, answers: inout HookAnswers, asks: Bool
    ) -> String? {
        guard let handler = offer.when else { return nil }
        if let text = answers.text(of: offer, in: spot.id) { return text }
        guard asks else { return nil }
        let card = target.entry.id
        let now = runs.answer(handler, of: spot, card: card, origin: origin, until: deadline) { [weak self] text in
            guard !text.isEmpty, let self, let session = menuSession, session.phase != .closing, session.target.entry.id == card, session.menu.parent == nil,
                  session.answers.text(of: offer, in: spot.id) == nil else { return }
            var answers = session.answers
            answers.keep(text, of: offer, in: spot.id)
            remake(session, answers: &answers)
        }
        if let now { answers.keep(now, of: offer, in: spot.id) }
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

    public func closeMenu(keepsFoot: Bool = false) {
        asOnePress {
            guard menu != nil else { return }
            if menuSession?.submenuRow != nil {
                menuSession?.submenuRow = nil
                host.hideSubmenu()
            }
            change(.sheet(isOpen: false), {
                menuSession?.phase = .closing
                if !keepsFoot, menuContentHeight != 0 { menuContentHeight = 0 }
            }, completion: { [weak self] in
                guard self?.menuSession?.phase == .closing else { return }
                self?.menuSession = nil
                self?.foldMenuFoot()
            })
        }
    }

    private func foldMenuFoot() {
        guard menuSession == nil, menuContentHeight != 0 else { return }
        change(.sheet(isOpen: false), { menuContentHeight = 0 })
    }

    public func pressMenu(row: Int) {
        asOnePress {
            guard let menu, menu.shown.indices.contains(row) else { return }
            guard menu.shown[row].children.isEmpty else { return point(at: .menuRow(row)) }
            _ = self.menu?.back()
            self.menu?.move(by: row - menu.selected)
            pressMenu()
        }
    }

    func pressMenu() {
        let isRunning = menu?.selectedRow.map { act(of: $0) != nil } ?? false
        guard let row = menu?.press(isRunning: isRunning), let target = menuTarget else { return }
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
}
