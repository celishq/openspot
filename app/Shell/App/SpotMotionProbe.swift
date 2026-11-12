import OpenspotCore
import AppKit
import QuartzCore
import ScreenCaptureKit

/// A run that opens and closes the sheet of one spot again and again, or with `OPENSPOT_ACTION` moves down its rows, types
/// in its search, picks the row `OPENSPOT_ROW`, types `OPENSPOT_TEXT` in the main search, opens the panel itself after
/// `OPENSPOT_PAUSE`, drags a card in Edit Spots or with `edit` starts and ends Edit Spots, and writes the time of each frame
/// to a file.
/// `OPENSPOT_ACTION=mouse` drags a card with mouse events instead, or with `OPENSPOT_ROW` holds it at the bottom `edge`,
/// pulls its `corner` handle or presses its `minus`, and writes whether it lifted or resized, the order, its size and
/// whether it is on the grid after.
/// `scripts/motion-perf.sh` starts it with `OPENSPOT_PROBE`. The panel stays almost clear, takes no focus and no clicks,
/// unless `OPENSPOT_SEEN` asks for a picture. With `OPENSPOT_SHOTS`, a drag saves a picture of each state to that folder
/// from a panel off every screen, `edit` saves Edit Spots with its dock from the panel at its place, and a card carried to
/// the dock, and neither times anything. `menu` saves the actions menu at its card and row. `tile` pulls the corner of a spot of the dock, or with `OPENSPOT_ROW=grid` of a
/// card, with mouse events on each frame, and writes how often its size changed.
@MainActor
final class SpotMotionProbe: NSObject {
    /// How long each open of the panel is timed: its fade and the reads that land in it.
    private static let openWindow: CFTimeInterval = 1
    private let model: SpotsModel
    private let panel: NSPanel
    private let output: String
    private let spot: String?
    private let presses: Int
    private let pause: Double
    /// Whether the panel shows in full, for a picture of it.
    private let isSeen: Bool
    private let action: String?
    /// The row that the `pick` action picks.
    private let row: String?
    /// The folder for the pictures of a drag.
    private let shots: String?
    /// Moves the lifted card on each frame of a drag, from the time of that frame.
    private var dragStep: ((CFTimeInterval) -> Void)?
    /// The text that the `search` action types in the main search.
    private let text: String
    private var link: CADisplayLink?
    private var frames: [CFTimeInterval] = []
    private var start: CFTimeInterval = 0
    /// The times that the `panel` action counts frames in, one from each open, so that the hidden panel counts for nothing.
    private var windows: [ClosedRange<CFTimeInterval>] = []
    /// The milliseconds of each open press of the `panel` action, on the main thread.
    private var pressTimes: [Double] = []

    init?(model: SpotsModel, panel: NSPanel, environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let output = environment["OPENSPOT_PROBE"] else { return nil }
        self.model = model
        self.panel = panel
        self.output = output
        spot = environment["OPENSPOT_SPOT"].flatMap { $0.isEmpty ? nil : $0 }
        presses = 2 * (Int(environment["OPENSPOT_CYCLES"] ?? "") ?? 20)
        pause = Double(environment["OPENSPOT_PAUSE"] ?? "") ?? 0.15
        isSeen = environment["OPENSPOT_SEEN"] != nil
        action = environment["OPENSPOT_ACTION"].flatMap { $0.isEmpty ? nil : $0 }
        row = environment["OPENSPOT_ROW"]
        shots = environment["OPENSPOT_SHOTS"]
        text = environment["OPENSPOT_TEXT"].flatMap { $0.isEmpty ? nil : $0 } ?? "2*(3+4)"
    }

    /// Shows the panel, waits for its reads, then starts the presses.
    func run(show: () -> Void) {
        show()
        if !isSeen {
            panel.alphaValue = 0.02
            panel.ignoresMouseEvents = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.begin() }
    }

    private func begin() {
        if action == "panel" { return beginOpens() }
        if action == "search" { return beginSearch() }
        if action == "drag" || action == "mouse" { return beginDrag() }
        if action == "edit" { return beginEdit() }
        if action == "menu", let shots { return shootMenus(into: shots) }
        if action == "jump" { return beginJump() }
        if action == "tile" {
            model.beginEditing()
            return DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.pullTile() }
        }
        let target = model.entries.first { spot == nil ? $0.kind == .widget && $0.spot.opens != nil : $0.id == spot }
        guard let target, let view = panel.contentView else { return finish(with: "no spot to open\n") }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        guard let action else {
            start = CACurrentMediaTime()
            return press(target.id, left: presses)
        }
        model.press(target.id)
        whenRowsArrive {
            self.start = CACurrentMediaTime()
            switch action {
            case "typing": self.type(left: self.presses)
            case "pick": self.pick()
            default: self.arrow(left: self.presses)
            }
        }
    }

    /// Starts Edit Spots under a capture of the display that holds only the panel's window, and writes how far the search
    /// field's row lies on the screen from where it lay before, in pixels, for each frame of the next second.
    private func beginJump() {
        Task { @MainActor in
            guard let watch = await SpotJumpWatch(panel: panel, row: SpotTokens.halo + SpotTokens.rowHeight / 2) else {
                return finish(with: "no capture\n")
            }
            try? await Task.sleep(for: .milliseconds(500))
            model.beginEditing()
            try? await Task.sleep(for: .seconds(1))
            let shifts = await watch.stop()
            let worst = shifts.map(abs).max() ?? 0
            finish(with: "worst shift \(worst) px in \(shifts.count) frames, contrast \(watch.contrast)\n" + shifts.map(String.init).joined(separator: " ") + "\n")
        }
    }

    /// Starts Edit Spots, and ends it as Done does, again and again.
    private func beginEdit() {
        guard let view = panel.contentView else { return finish(with: "no panel\n") }
        if let shots { return shootEdit(into: shots) }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        start = CACurrentMediaTime()
        edit(left: presses)
    }

    private func edit(left: Int) {
        guard left > 0 else { return end() }
        if left % 2 == 0 { model.beginEditing() } else { model.endEditing() }
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.edit(left: left - 1) }
    }

    /// Saves a picture of Edit Spots with its store a second after it starts, then of the tip of the first card's eye, then of
    /// the listing of the store's first row, then the pictures of a carried card, then of the panel after Edit Spots ends and
    /// starts again.
    private func shootEdit(into folder: String) {
        model.beginEditing()
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.save(to: "\(folder)/dock.png")
            self.model.tip = self.model.visible.first.map { SpotTip(id: $0.id, anchor: .trailingCorner, text: "Hide from grid") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.save(to: "\(folder)/tip.png")
                self.model.tip = nil
                if let id = self.model.dock.shown.first?.id { self.model.openListing(id) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.save(to: "\(folder)/listing.png")
                    if let id = self.model.dock.opened { self.model.openListing(id) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.shootCarry(into: folder) }
                }
            }
        }
    }

    /// Saves a picture of the actions menu on a small card on the left, a small card on the right and a wide card, of a
    /// search in it, and of the menu on a row of `OPENSPOT_SPOT`'s list.
    private func shootMenus(into folder: String) {
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let cards: [(String, (SpotPlacement) -> Bool)] = [
            ("left", { $0.size == .small && $0.column == 0 }),
            ("right", { $0.size == .small && $0.column == SpotTokens.columns - 1 }),
            ("wide", { $0.size.columns > 1 }),
        ]
        let shots = cards.compactMap { name, fits in model.placements.first(where: fits).map { (name, $0.index) } }
        shootMenu(shots, into: folder)
    }

    private func shootMenu(_ shots: [(String, Int)], into folder: String) {
        guard let (name, index) = shots.first else { return shootSearch(into: folder) }
        model.selected = index
        _ = model.handleKey(ActionKey(name: "k", isCommand: true))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.save(to: "\(folder)/\(name).png")
            self.model.closeMenu()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.shootMenu(Array(shots.dropFirst()), into: folder) }
        }
    }

    private func shootSearch(into folder: String) {
        for placement in model.placements {
            model.selected = placement.index
            _ = model.handleKey(ActionKey(name: "k", isCommand: true))
            if model.menu?.isSearchable == true { break }
            model.closeMenu()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.save(to: "\(folder)/long.png")
            self.model.searchMenu("co")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.save(to: "\(folder)/search.png")
            self.model.closeMenu()
            guard let id = self.spot else { return self.finish(with: "shots\n") }
            self.model.press(id)
            self.whenRowsArrive {
                self.model.moveItemLine(by: 2)
                _ = self.model.handleKey(ActionKey(name: "k", isCommand: true))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.save(to: "\(folder)/row.png")
                    self.finish(with: "shots\n")
                }
            }
        }
    }

    /// Saves pictures of `OPENSPOT_SPOT` carried over the dock, a second after its release there, then carried from the dock
    /// over the grid's first card, a second after its release there, and of the dock's first spot pulled a column wider and
    /// a row taller.
    private func shootCarry(into folder: String) {
        guard let id = spot, let index = model.visible.firstIndex(where: { $0.id == id }), let dock = model.dockFrame else {
            return finish(with: "shots\n")
        }
        let rect = model.placements[index].rect
        let origin = SpotTokens.gridOrigin(scrollOffset: model.gridScroll)
        let move = CGSize(width: dock.midX - origin.x - rect.midX, height: dock.midY - origin.y - rect.midY)
        model.dragSpot(id, by: CGSize(width: 1, height: 1))
        model.dragSpot(id, by: move)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.save(to: "\(folder)/carried.png")
            self.model.dropSpot(by: move)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.save(to: "\(folder)/dropped.png")
                self.shootArrival(of: id, into: folder)
            }
        }
    }

    /// Carries a spot of the dock over the left half of the grid's first card, and saves a picture of it there and a second
    /// after its release.
    private func shootArrival(of id: String, into folder: String) {
        guard let dock = model.dockFrame, let index = model.dock.shown.firstIndex(where: { $0.id == id }), let first = model.placements.first else {
            return finish(with: "shots\n")
        }
        let tile = model.dock.rects[index]
        let origin = SpotTokens.gridOrigin(scrollOffset: model.gridScroll)
        let target = CGPoint(x: origin.x + first.rect.minX + first.rect.width / 4, y: origin.y + first.rect.midY)
        let start = CGPoint(x: dock.minX + SpotDock.rowsOrigin.x + tile.midX, y: dock.minY + SpotDock.rowsOrigin.y + tile.midY - model.dockScroll)
        let move = CGSize(width: target.x - start.x, height: target.y - start.y)
        model.dragDockSpot(id, by: CGSize(width: 1, height: 1))
        model.dragDockSpot(id, by: move)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.save(to: "\(folder)/arriving.png")
            self.model.dropDockSpot(by: move)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.save(to: "\(folder)/arrived.png")
                self.shootTileResize(into: folder)
            }
        }
    }

    /// Pulls the corner of the dock's first spot one column right and one row down, and saves a picture of it.
    private func shootTileResize(into folder: String) {
        guard let id = model.dock.shown.first?.id else { return finish(with: "shots\n") }
        let move = CGSize(width: SpotTokens.cell + SpotTokens.columnGap, height: SpotTokens.rowHeight + SpotTokens.rowGap)
        model.resizeSpot(id, by: .zero)
        model.resizeSpot(id, by: move)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.save(to: "\(folder)/tile-resized.png")
            self.model.cancelResize()
            self.shootEnd(into: folder)
        }
    }

    /// Ends Edit Spots and saves a picture of the panel a second later, at its place with the store put away, then starts it
    /// again and saves a picture of the store as it comes back.
    private func shootEnd(into folder: String) {
        model.endEditing()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.save(to: "\(folder)/ended.png")
            self.model.beginEditing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.save(to: "\(folder)/reopened.png")
                self.finish(with: "shots\n")
            }
        }
    }

    /// Presses the corner handle of the grid's smallest card with more than one size, and pulls it two columns right and a
    /// row down and back, once for every four presses, with a mouse event on each frame. The app takes the focus, as the
    /// events reach only the key window.
    private func pullTile() {
        let cards = model.visible.indices.filter { model.visible[$0].isOnGrid && model.sizes(of: model.visible[$0]).count > 1 }
        let card = cards.min { model.visible[$0].size.columns * model.visible[$0].size.rows < model.visible[$1].size.columns * model.visible[$1].size.rows }
        guard let window = panel as? SpotsPanel, let view = panel.contentView, let card else {
            return finish(with: "no card to resize\n")
        }
        let id = model.visible[card].id
        let grid = SpotTokens.gridOrigin(scrollOffset: model.gridScroll)
        let end = CGPoint(x: grid.x + model.placements[card].rect.maxX, y: grid.y + model.placements[card].rect.maxY)
        panel.ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        let inset = SpotTokens.keycap / 2
        let corner = CGPoint(x: window.place.panel.x + end.x - inset, y: window.place.panel.y + end.y - inset)
        let reach = CGSize(width: 2 * (SpotTokens.cell + SpotTokens.columnGap), height: SpotTokens.rowHeight + SpotTokens.rowGap)
        func post(_ type: NSEvent.EventType, _ share: CGFloat) {
            let point = NSPoint(x: corner.x + reach.width * share, y: view.bounds.height - corner.y - reach.height * share)
            guard let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1) else { return }
            NSApp.postEvent(event, atStart: false)
        }
        let size = { self.model.visible.first { $0.id == id }?.size }
        var last = size()
        var changes = 0
        var steps: [String] = []
        var resized = false
        let leg = 0.5
        let tours = Double(max(presses / 4, 1))
        var begun: CFTimeInterval?
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        dragStep = { [weak self] now in
            guard let self else { return }
            guard let first = begun else {
                begun = now
                start = CACurrentMediaTime()
                return post(.leftMouseDown, 0)
            }
            let time = now - first
            resized = resized || model.resize != nil
            if size() != last {
                changes += 1
                last = size()
                steps.append(String(format: "%.2f %@", time, last?.name ?? "none"))
            }
            guard time < tours * 2 * leg else {
                post(.leftMouseUp, 0)
                dragStep = nil
                return DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.finish(with: self.report() + "\(id) resized \(resized), size changes \(changes)\n" + steps.joined(separator: "\n") + "\n")
                }
            }
            let phase = time.truncatingRemainder(dividingBy: 2 * leg) / leg
            post(.leftMouseDragged, CGFloat(phase < 1 ? phase : 2 - phase))
        }
    }

    /// Opens the panel again and again, once its first reads have ended, each after the pause, so that each open reads its
    /// scripts as an open of a person does.
    private func beginOpens() {
        guard !model.runs.isReading else {
            return DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.beginOpens() }
        }
        guard let view = panel.contentView, let panel = panel as? SpotsPanel else { return finish(with: "no panel\n") }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        panel.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.open(panel, left: self.presses / 2) }
    }

    /// Opens the panel as the key does, but with no focus, and times the press. It hides the panel when its window ends.
    private func open(_ panel: SpotsPanel, left: Int) {
        guard left > 0 else { return finish(with: report()) }
        panel.alphaValue = 0.02
        let pressed = CACurrentMediaTime()
        panel.place(over: NSWorkspace.shared.frontmostApplication)
        model.panelWillShow(holding: [])
        panel.orderFrontRegardless()
        pressTimes.append((CACurrentMediaTime() - pressed) * 1000)
        frames.append(pressed)
        windows.append(pressed...(pressed + Self.openWindow))
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.openWindow) {
            panel.hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + self.pause) { self.open(panel, left: left - 1) }
        }
    }

    /// Types the text in the main search once the first reads have ended.
    private func beginSearch() {
        guard !model.runs.isReading else {
            return DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.beginSearch() }
        }
        guard let view = panel.contentView else { return finish(with: "no panel\n") }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        start = CACurrentMediaTime()
        search(left: presses)
    }

    /// Types the text a letter at a time from an empty search, again and again, then types it whole and adds the title and
    /// the detail of each card that shows to the report.
    private func search(left: Int) {
        guard left > 0 else {
            model.searchText = text
            return DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let shown = self.model.visible.map { "\($0.state.title) · \($0.state.subtitle ?? "")" }
                self.finish(with: self.report() + "shows:\n" + shown.joined(separator: "\n") + "\n")
            }
        }
        model.searchText = String(text.prefix((presses - left) % (text.count + 1)))
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.search(left: left - 1) }
    }

    /// Runs the work a second after the open sheet holds its rows.
    private func whenRowsArrive(_ work: @escaping () -> Void) {
        guard let list = model.openItems, list.holdsItems, !list.isLoading else {
            return DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.whenRowsArrive(work) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    /// Moves down one line of the open rows for each step, and back up for each second half of the steps.
    private func arrow(left: Int) {
        guard left > 0 else { return end() }
        model.moveItemLine(by: left > presses / 2 ? 1 : -1)
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.arrow(left: left - 1) }
    }

    /// Types a word into the search of the open rows a letter at a time, then clears it, again and again.
    private func type(left: Int) {
        guard left > 0 else { return end() }
        let word = "smile"
        let length = left % (word.count + 1)
        model.searchText = String(word.prefix(length))
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.type(left: left - 1) }
    }

    /// Picks the row `OPENSPOT_ROW` of the open rows, as a press of Enter on it does.
    private func pick() {
        if let item = model.openItems?.shown.first(where: { $0.run == row }) { model.runItem(item) }
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.end() }
    }

    private func end() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.finish(with: self.report()) }
    }

    private func press(_ id: String, left: Int) {
        guard left > 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.finish(with: self.report()) }
            return
        }
        if left % 2 == 0 {
            model.press(id)
        } else {
            model.closeList(moving: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.press(id, left: left - 1) }
    }

    @objc private func tick(_ link: CADisplayLink) {
        frames.append(link.timestamp)
        dragStep?(link.timestamp)
    }

    /// Lifts the last card on the grid, or `OPENSPOT_SPOT`, in Edit Spots, and moves it along a tour of the grid once for
    /// every two presses: to the first place, to the middle, and back to where it started, with a rest at each stop.
    private func beginDrag() {
        model.beginEditing()
        guard let id = spot ?? model.visible.last(where: \.isOnGrid)?.id, let index = model.visible.firstIndex(where: { $0.id == id }),
              let view = panel.contentView else { return finish(with: "no card to drag\n") }
        let rect = model.placements[index].rect
        let stops = [
            CGPoint(x: rect.midX, y: rect.midY),
            CGPoint(x: SpotTokens.cell / 2, y: SpotTokens.rowHeight / 2),
            CGPoint(x: SpotTokens.gridWidth / 2, y: SpotGrid.height(of: model.placements) / 2),
            CGPoint(x: rect.midX, y: rect.midY)
        ].map { CGSize(width: $0.x - rect.midX, height: $0.y - rect.midY) }
        if let shots { return shoot(id, stops: stops, into: shots) }
        if action == "mouse" { return press(id, at: rect, by: stops[1]) }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        let leg = 0.5
        var tours = max(presses / 4, 1)
        var tourStart: CFTimeInterval?
        dragStep = { [weak self] now in
            guard let self else { return }
            let begun = tourStart ?? now
            tourStart = begun
            let time = now - begun
            let index = min(Int(time / leg), stops.count - 2)
            let share = min(max((time - Double(index) * leg) / (leg / 2), 0), 1)
            let from = stops[index], to = stops[index + 1]
            let translation = CGSize(width: from.width + (to.width - from.width) * share, height: from.height + (to.height - from.height) * share)
            guard time < Double(stops.count - 1) * leg else {
                model.dropSpot(by: translation)
                tourStart = nil
                tours -= 1
                if tours == 0 {
                    dragStep = nil
                    end()
                }
                return
            }
            model.dragSpot(id, by: translation)
        }
        start = CACurrentMediaTime()
    }

    /// Presses the card at this place, moves the mouse this far in steps and lets go, through events put in the app's queue
    /// for a panel off every screen, as a person's mouse sends them. The press starts at the card's centre, its corner
    /// handle, which it pulls down a row, or its minus, which it only clicks. At the edge it rests 1.5 s before it lets go.
    /// The panel stays open when another app takes the focus. It logs the drag after each step, and each 10 ms after the last.
    private func press(_ id: String, at rect: CGRect, by move: CGSize) {
        panel.setFrameOrigin(NSPoint(x: -9000, y: -9000))
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        model.isSettlingDrop = true
        let height = panel.contentView?.bounds.height ?? 0
        let inset = SpotTokens.keycap / 2
        let point = row == "corner" ? CGPoint(x: rect.maxX - inset, y: rect.maxY - inset) : row == "minus" ? CGPoint(x: rect.minX + inset, y: rect.minY + inset) : CGPoint(x: rect.midX, y: rect.midY)
        let edgeMove = CGSize(width: 0, height: SpotTokens.panelHeight - SpotTokens.halo - SpotTokens.hintBlock - 10 - (SpotTokens.gridTop + rect.midY))
        let translation = row == "corner" ? CGSize(width: 0, height: SpotTokens.rowHeight + SpotTokens.rowGap) : row == "minus" ? .zero : row == "edge" ? edgeMove : move
        let start = NSPoint(x: SpotTokens.halo + point.x, y: height - (SpotTokens.gridTop + point.y))
        let size = { self.model.visible.firstIndex { $0.id == id }.map { self.model.placements[$0].size.name } ?? "none" }
        let sizeBefore = size()
        let before = model.visible.map(\.id)
        var lifted = false
        var resizing = false
        var maxScroll: CGFloat = 0
        func scrolled(_ view: NSView?) -> CGFloat? {
            guard let view else { return nil }
            if let scroll = view as? NSScrollView { return scroll.contentView.bounds.minY }
            return view.subviews.lazy.compactMap(scrolled).first
        }
        func post(_ type: NSEvent.EventType, _ share: CGFloat) {
            let point = NSPoint(x: start.x + translation.width * share, y: start.y - translation.height * share)
            guard let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1) else { return }
            NSApp.postEvent(event, atStart: false)
        }
        let rest: [() -> Void] = row == "edge" ? Array(repeating: {}, count: 75) : []
        let steps = [{ post(.leftMouseDown, 0) }] + (1...20).map { step in { post(.leftMouseDragged, CGFloat(step) / 20) } } + rest + [{ post(.leftMouseUp, 1) }]
        var log: [String] = []
        func note() {
            log.append("drag \(model.drag.map { "\($0.id) at \($0.place)" } ?? "none") landing \(model.landing ?? "none") lift \(model.lift.offset)")
        }
        func run(_ left: ArraySlice<() -> Void>) {
            guard let next = left.first else {
                (1...20).forEach { tick in DispatchQueue.main.asyncAfter(deadline: .now() + Double(tick) * 0.01, execute: note) }
                return DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    let entry = self.model.visible.first { $0.id == id }
                    self.finish(with: "lifted \(lifted)\nresizing \(resizing)\nmost scroll \(maxScroll)\nbefore \(before)\nafter \(self.model.visible.map(\.id))\nsize \(sizeBefore) to \(size())\non grid \(entry?.isOnGrid ?? false)\n" + log.joined(separator: "\n") + "\n")
                }
            }
            next()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                lifted = lifted || self.model.drag != nil
                resizing = resizing || self.model.resize != nil
                maxScroll = max(maxScroll, scrolled(self.panel.contentView) ?? 0)
                note()
                run(left.dropFirst())
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { run(steps[...]) }
    }

    /// Saves a picture of Edit Spots, of the card 30 ms into its lift and once the cards made room near the first place,
    /// 60 ms into its drop there and after it, and of the card pulled a row taller by its corner and kept, from a panel off
    /// every screen.
    private func shoot(_ id: String, stops: [CGSize], into folder: String) {
        panel.setFrameOrigin(NSPoint(x: -9000, y: -9000))
        panel.alphaValue = 1
        let near = CGSize(width: stops[1].width + SpotTokens.cell / 3, height: stops[1].height + SpotTokens.rowHeight / 3)
        let states: [(name: String, wait: Double, act: () -> Void)] = [
            ("edit", 1, {}),
            ("handle", 1, { self.model.resizeSpot(id, by: .zero) }),
            ("lifting", 0.03, {
                self.model.cancelResize()
                self.model.dragSpot(id, by: CGSize(width: 1, height: 1))
            }),
            ("lifted", 1, { self.model.dragSpot(id, by: near) }),
            ("dropping", 0.06, { self.model.dropSpot(by: near) }),
            ("dropped", 1, {}),
            ("resized", 1, { self.model.resizeSpot(id, by: CGSize(width: 0, height: SpotTokens.rowHeight + SpotTokens.rowGap)) }),
            ("kept", 1, { self.model.dropResize() })
        ]
        func next(_ left: ArraySlice<(name: String, wait: Double, act: () -> Void)>) {
            guard let state = left.first else { return finish(with: "shots\n") }
            state.act()
            DispatchQueue.main.asyncAfter(deadline: .now() + state.wait) {
                self.save(to: "\(folder)/\(state.name).png")
                next(left.dropFirst())
            }
        }
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        next(states[...])
    }

    /// Writes the panel's content as a PNG over the colour of a window, since the blur draws nothing off screen.
    private func save(to path: String) {
        guard let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let image = NSImage(size: view.bounds.size, flipped: false) { bounds in
            NSColor(SpotTheme.window).setFill()
            bounds.fill()
            bitmap.draw(in: bounds)
            return true
        }
        guard let tiff = image.tiffRepresentation, let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        FileManager.default.createFile(atPath: path, contents: data)
    }

    /// The frame times from the first press, or in the windows of the opens, in milliseconds: their spread, then each one.
    private func report() -> String {
        let counted = { (time: CFTimeInterval) in self.windows.isEmpty ? time >= self.start : self.windows.contains { $0.contains(time) } }
        let gaps = zip(frames.dropFirst(), frames).filter { counted($0.1) }.map { ($0.0 - $0.1) * 1000 }
        let sorted = gaps.sorted()
        guard !sorted.isEmpty else { return "no frames\n" }
        let budget = 1000 / Double(NSScreen.main?.maximumFramesPerSecond ?? 120)
        let at = { (share: Double) in sorted[min(Int(Double(sorted.count) * share), sorted.count - 1)] }
        let late = gaps.filter { $0 > budget * 1.05 }
        let dropped = gaps.map { max(Int(($0 / budget).rounded()) - 1, 0) }.reduce(0, +)
        let seconds = gaps.reduce(0, +) / 1000
        let presses = pressTimes.sorted()
        let press = presses.isEmpty ? "" : String(format: ", press p50 %.2f ms, worst %.2f ms", presses[presses.count / 2], presses.last ?? 0)
        let head = String(
            format: "fps %.0f, p50 %.1f ms, p90 %.1f ms, p99 %.1f ms, worst %.1f ms, late %d of %d, dropped %d%@\n",
            Double(gaps.count) / seconds, at(0.5), at(0.9), at(0.99), sorted.last ?? 0, late.count, gaps.count, dropped, press
        )
        return head + gaps.map { String(format: "%.1f", $0) }.joined(separator: " ") + "\n"
    }

    private func finish(with text: String) {
        link?.invalidate()
        FileManager.default.createFile(atPath: output, contents: Data(text.utf8))
        exit(0)
    }
}

/// A capture of the display that holds only the panel's window. For each frame it finds how far one row of the panel lies
/// from where it lay in the first frame.
private final class SpotJumpWatch: NSObject, SCStreamOutput, @unchecked Sendable {
    private let stream: SCStream
    private let rowY: Int
    private let lock = NSLock()
    private var first: [Double]?
    private var shifts: [Int] = []

    @MainActor init?(panel: NSPanel, row: CGFloat) async {
        guard let content = try? await SCShareableContent.current,
              let window = content.windows.first(where: { $0.windowID == CGWindowID(panel.windowNumber) }),
              let screen = panel.screen,
              let display = content.displays.first(where: { $0.frame.width == screen.frame.width && $0.frame.height == screen.frame.height }) else { return nil }
        let scale = screen.backingScaleFactor
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * scale)
        config.height = Int(screen.frame.height * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 240)
        config.showsCursor = false
        rowY = Int((screen.frame.maxY - panel.frame.maxY + row) * scale)
        stream = SCStream(filter: SCContentFilter(display: display, including: [window]), configuration: config, delegate: nil)
        super.init()
        try? stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "jump"))
        do { try await stream.startCapture() } catch { return nil }
    }

    func stop() async -> [Int] {
        try? await stream.stopCapture()
        return lock.withLock { shifts }
    }

    /// The range of brightness along the first row, which is 0 when the capture holds nothing of the panel.
    var contrast: Double {
        lock.withLock { (first?.max() ?? 0) - (first?.min() ?? 0) }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              (attachments.first?[.status] as? Int).flatMap(SCFrameStatus.init) == .complete,
              let pixels = CMSampleBufferGetImageBuffer(buffer) else { return }
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixels), rowY < CVPixelBufferGetHeight(pixels) else { return }
        let width = CVPixelBufferGetWidth(pixels)
        let line = base.advanced(by: rowY * CVPixelBufferGetBytesPerRow(pixels)).assumingMemoryBound(to: UInt8.self)
        let row = (0..<width).map { x in Double(Int(line[4 * x]) + Int(line[4 * x + 1]) + Int(line[4 * x + 2])) / 765 }
        lock.lock()
        defer { lock.unlock() }
        guard let first else { return self.first = row }
        shifts.append(Self.shift(of: row, from: first))
    }

    /// The shift of a row against the first row, within 600 pixels, that makes the two most alike.
    private static func shift(of row: [Double], from first: [Double]) -> Int {
        let count = min(row.count, first.count)
        func cost(_ shift: Int) -> Double {
            stride(from: 0, to: count, by: 2).reduce(0) { sum, x in
                let moved = x + shift
                guard moved >= 0, moved < count else { return sum }
                return sum + abs(row[moved] - first[x])
            }
        }
        return stride(from: -600, through: 600, by: 1).min { cost($0) < cost($1) } ?? 0
    }
}
