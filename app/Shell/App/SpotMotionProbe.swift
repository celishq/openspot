import OpenspotCore
import AppKit
import QuartzCore
import ScreenCaptureKit

@MainActor
final class SpotMotionProbe: NSObject {
    private static let openWindow: CFTimeInterval = 1
    private let model: SpotsModel
    private let panel: NSPanel
    private let output: String
    private let spot: String?
    private let presses: Int
    private let pause: Double
    private let isSeen: Bool
    private let action: String?
    private let row: String?
    private let shotsFolder: String?
    private var dragStep: ((CFTimeInterval) -> Void)?
    private let searchText: String
    private var link: CADisplayLink?
    private var frames: [CFTimeInterval] = []
    private var start: CFTimeInterval = 0
    private var countedWindows: [ClosedRange<CFTimeInterval>] = []
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
        shotsFolder = environment["OPENSPOT_SHOTS"]
        searchText = environment["OPENSPOT_TEXT"].flatMap { $0.isEmpty ? nil : $0 } ?? "2*(3+4)"
    }

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
        if action == "menu" { return beginMenus() }
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

    private func beginEdit() {
        guard let view = panel.contentView else { return finish(with: "no panel\n") }
        if let shotsFolder { return shootEdit(into: shotsFolder) }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        start = CACurrentMediaTime()
        edit(left: presses)
    }

    private func beginMenus() {
        if let shotsFolder { return shootMenus(into: shotsFolder) }
        guard let view = panel.contentView else { return finish(with: "no panel\n") }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        model.selected = model.placements.first { $0.size == .small }?.index ?? 0
        start = CACurrentMediaTime()
        toggleMenu(left: presses)
    }

    private func toggleMenu(left: Int) {
        guard left > 0 else { return end() }
        _ = model.handleKey(ActionKey(name: "k", isCommand: true))
        DispatchQueue.main.asyncAfter(deadline: .now() + pause * 3) { self.toggleMenu(left: left - 1) }
    }

    private func edit(left: Int) {
        guard left > 0 else { return end() }
        if left % 2 == 0 { model.beginEditing() } else { model.endEditing() }
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.edit(left: left - 1) }
    }

    private func shootEdit(into folder: String) {
        model.beginEditing()
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.save(to: "\(folder)/edit.png")
            self.model.tip = self.model.visible.first.map { SpotTip(id: $0.id, anchor: .trailingCorner, text: "Hide from grid") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.save(to: "\(folder)/tip.png")
                self.model.tip = nil
                self.shootEnd(into: folder)
            }
        }
    }

    private func shootMenus(into folder: String) {
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        let cards: [(String, (SpotPlacement) -> Bool)] = [
            ("left", { $0.size == .small && $0.column == 0 }),
            ("right", { $0.size == .small && $0.column == SpotTokens.columns - 1 }),
            ("wide", { $0.size.columns > 1 }),
        ]
        let shots = cards.compactMap { name, fits in model.placements.first(where: fits).map { (name, $0.index) } }
        shootMenu(shots, into: folder)
    }

    private func shootMenu(_ shots: [(String, Int)], into folder: String) {
        guard let (name, index) = shots.first else { return shootSubmenu(into: folder) }
        model.selected = index
        _ = model.handleKey(ActionKey(name: "k", isCommand: true))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.save(to: "\(folder)/\(name).png")
            self.model.closeMenu()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.shootMenu(Array(shots.dropFirst()), into: folder) }
        }
    }

    private func shootSubmenu(into folder: String) {
        model.selected = model.placements.first { $0.size == .small && $0.column == 0 }?.index ?? 0
        _ = model.handleKey(ActionKey(name: "k", isCommand: true))
        if let action = model.menu?.shown.first(where: { !$0.children.isEmpty })?.action { model.menu?.select(action) }
        _ = model.handleKey(ActionKey(name: "right"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.saveWithChildren(to: "\(folder)/submenu.png")
            self.model.closeMenu()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.shootSearch(into: folder) }
        }
    }

    private func saveWithChildren(to path: String) {
        let windows = [panel as NSWindow] + (panel.childWindows ?? []).filter(\.isVisible)
        let whole = windows.map(\.frame).reduce(panel.frame) { $0.union($1) }
        let image = NSImage(size: whole.size, flipped: false) { bounds in
            NSColor(SpotTheme.window).setFill()
            bounds.fill()
            for window in windows {
                guard let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                bitmap.draw(in: window.frame.offsetBy(dx: -whole.minX, dy: -whole.minY))
            }
            return true
        }
        guard let tiff = image.tiffRepresentation, let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        FileManager.default.createFile(atPath: path, contents: data)
    }

    private func shootSearch(into folder: String) {
        for placement in model.placements {
            model.selected = placement.index
            _ = model.handleKey(ActionKey(name: "k", isCommand: true))
            if model.menu?.isSearchable == true { break }
            model.closeMenu()
        }
        save(to: "\(folder)/long-moving.png")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.save(to: "\(folder)/long.png")
            self.saveSharp(to: "\(folder)/field-focused.png")
            self.model.searchMenu("co")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.save(to: "\(folder)/search.png")
            self.panel.makeFirstResponder(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.saveSharp(to: "\(folder)/field-unfocused.png")
            self.model.closeMenu()
            guard let id = self.spot else { return self.finish(with: "shots\n") }
            self.model.press(id)
            self.whenRowsArrive {
                self.model.moveItemLine(by: 2)
                _ = self.model.handleKey(ActionKey(name: "k", isCommand: true))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.save(to: "\(folder)/row.png")
                    self.model.closeMenu()
                    self.shootResults(into: folder)
                }
            }
        }
    }

    private func shootResults(into folder: String) {
        _ = model.stepBack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let word = self.model.visible.first?.state.title.split(separator: " ").first.map(String.init) ?? "a"
            self.model.searchText = word
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                _ = self.model.handleKey(ActionKey(name: "k", isCommand: true))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.save(to: "\(folder)/results.png")
                    self.finish(with: "shots\n")
                }
            }
        }
    }

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

    private func pullTile() {
        let cards = model.visible.indices.filter { model.visible[$0].isOnGrid && model.sizes(of: model.visible[$0]).count > 1 }
        let card = cards.min { model.visible[$0].size.columns * model.visible[$0].size.rows < model.visible[$1].size.columns * model.visible[$1].size.rows }
        guard let window = panel as? SpotsPanel, let view = panel.contentView, let card else {
            return finish(with: "no card to resize\n")
        }
        let id = model.visible[card].id
        let grid = model.gridOrigin
        let end = CGPoint(x: grid.x + model.placements[card].rect.maxX, y: grid.y + model.placements[card].rect.maxY)
        panel.ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
        let inset = SpotTokens.keycap / 2
        let corner = CGPoint(x: window.place.left + end.x - inset, y: end.y - inset)
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

    private func open(_ panel: SpotsPanel, left: Int) {
        guard left > 0 else { return finish(with: report()) }
        panel.alphaValue = 0.02
        let pressed = CACurrentMediaTime()
        panel.place(over: NSWorkspace.shared.frontmostApplication)
        model.panelWillShow(holding: [])
        panel.orderFrontRegardless()
        pressTimes.append((CACurrentMediaTime() - pressed) * 1000)
        frames.append(pressed)
        countedWindows.append(pressed...(pressed + Self.openWindow))
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.openWindow) {
            panel.hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + self.pause) { self.open(panel, left: left - 1) }
        }
    }

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

    private func search(left: Int) {
        guard left > 0 else {
            model.searchText = searchText
            return DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let shown = self.model.visible.map { "\($0.state.title) · \($0.state.subtitle ?? "")" }
                self.finish(with: self.report() + "shows:\n" + shown.joined(separator: "\n") + "\n")
            }
        }
        model.searchText = String(searchText.prefix((presses - left) % (searchText.count + 1)))
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.search(left: left - 1) }
    }

    private func whenRowsArrive(_ work: @escaping @MainActor @Sendable () -> Void) {
        guard let list = model.openItems, list.holdsItems, !list.isLoading else {
            return DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.whenRowsArrive(work) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func arrow(left: Int) {
        guard left > 0 else { return end() }
        model.moveItemLine(by: left > presses / 2 ? 1 : -1)
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.arrow(left: left - 1) }
    }

    private func type(left: Int) {
        guard left > 0 else { return end() }
        let word = "smile"
        let length = left % (word.count + 1)
        model.searchText = String(word.prefix(length))
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.type(left: left - 1) }
    }

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
        if let shotsFolder { return shoot(id, stops: stops, into: shotsFolder) }
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

    private func saveSharp(to path: String) {
        guard let view = panel.contentView, let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width) * 2, pixelsHigh: Int(view.bounds.height) * 2, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        bitmap.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: bitmap)
        FileManager.default.createFile(atPath: path, contents: bitmap.representation(using: .png, properties: [:]))
    }

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

    private func report() -> String {
        let counted = { (time: CFTimeInterval) in self.countedWindows.isEmpty ? time >= self.start : self.countedWindows.contains { $0.contains(time) } }
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
