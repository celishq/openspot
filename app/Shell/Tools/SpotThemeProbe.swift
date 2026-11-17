#if OPENSPOT_TOOLS
import AppKit
import OpenspotCore
import QuartzCore

@MainActor
final class SpotThemeProbe: NSObject {
    private let model: SpotsModel
    private let motion: String
    private let seconds: Double
    private let finish: (String) -> Void
    private var window: NSWindow?
    private var link: CADisplayLink?
    private var frames: [CFTimeInterval] = []
    private var start: CFTimeInterval?
    private var step: ((CFTimeInterval) -> Void)?
    private var notes: [String] = []
    private var changes = 0

    init(model: SpotsModel, motion: String, seconds: Double, finish: @escaping (String) -> Void) {
        self.model = model
        self.motion = motion
        self.seconds = seconds
        self.finish = finish
    }

    func run() {
        SpotThemeWindow.show(model: model)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.begin() }
    }

    private func begin() {
        guard let window = NSApp.windows.first(where: { $0.frameAutosaveName == "theme-window" }), let view = window.contentView,
              let editor = SpotThemeWindow.shownModel else { return finish("no theme window\n") }
        self.window = window
        if editor.isBuiltIn {
            editor.duplicate()
            return DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.begin() }
        }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        watch(editor)
        switch motion {
        case "scroll": scroll(in: view)
        case "slider": slide(editor, in: view)
        case "colour": colour(in: view)
        case "mark": drag(editor, in: view)
        case "stepper": stepper(editor, in: view)
        default: idle()
        }
    }

    private func watch(_ editor: SpotThemeModel) {
        withObservationTracking {
            _ = SpotLoadedTheme.shared.palette.ink
            _ = SpotLoadedTheme.shared.palette.dark
            _ = editor.layout
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.start != nil { self.changes += 1 }
                self.watch(editor)
            }
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        frames.append(link.timestamp)
        step?(link.timestamp)
    }

    private func timed(_ work: @escaping (CFTimeInterval) -> Void) {
        step = { [weak self] now in
            guard let self else { return }
            let begun = start ?? now
            start = begun
            let time = now - begun
            guard time < seconds else {
                step = nil
                return end(with: "")
            }
            work(time)
        }
    }

    private func idle() {
        timed { _ in }
    }

    private func scroll(in view: NSView) {
        guard let scroll = Self.all(NSScrollView.self, in: view).filter({ ($0.documentView?.frame.height ?? 0) > $0.bounds.height * 2 })
            .min(by: { $0.frame.minX < $1.frame.minX }), let window else { return end(with: "no rows scroll\n") }
        let place = scroll.convert(CGPoint(x: scroll.bounds.midX, y: scroll.bounds.midY), to: nil)
        let screen = window.convertPoint(toScreen: place)
        let top = (NSScreen.screens.first?.frame.height ?? 0) - screen.y
        let leg = 0.75
        var phase: Int64 = 1
        let first = scroll.contentView.bounds.minY
        var most: CGFloat = 0
        timed { time in
            let down = Int(time / leg) % 2 == 0
            guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: down ? -12 : 12, wheel2: 0, wheel3: 0) else { return }
            event.location = CGPoint(x: screen.x, y: top)
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
            phase = 2
            guard let scrolled = NSEvent(cgEvent: event) else { return }
            scroll.scrollWheel(with: scrolled)
            most = max(most, abs(scroll.contentView.bounds.minY - first))
            self.notes = ["most scroll \(Int(most))"]
        }
    }

    private func slide(_ editor: SpotThemeModel, in view: NSView) {
        guard let scroll = rowsScroll(in: view), let cell = cell(of: .strength, in: editor, scroll: scroll) else { return end(with: "no slider\n") }
        let width = SpotTokens.themeCellWidth - SpotTokens.themeNumberWidth - 16 - 2 * SpotTokens.themeSpacing
        let knob = CGPoint(x: cell.minX + width / 2, y: cell.midY)
        let reach = width * 0.4
        var begun = false
        timed { time in
            if !begun {
                begun = true
                self.post(.leftMouseDown, at: knob)
                return
            }
            let share = sin(time * 2 * .pi / 1.5)
            if time > self.seconds - 0.05 { return self.post(.leftMouseUp, at: CGPoint(x: knob.x + reach * share, y: knob.y)) }
            self.post(.leftMouseDragged, at: CGPoint(x: knob.x + reach * share, y: knob.y))
        }
    }

    private func rowsScroll(in view: NSView) -> NSScrollView? {
        Self.all(NSScrollView.self, in: view).filter { ($0.documentView?.frame.height ?? 0) > $0.bounds.height * 2 }.min { $0.frame.minX < $1.frame.minX }
    }

    private func cell(of kind: ThemeKind, in editor: SpotThemeModel, scroll: NSScrollView) -> CGRect? {
        let lines = editor.groups.flatMap { group in [nil] + (editor.grouped[group] ?? []).map { Optional($0) } }
        guard let line = lines.firstIndex(where: { $0?.kind == kind }), let row = lines[line], let document = scroll.documentView else { return nil }
        let cells = CGFloat(row.cells.count)
        let pitch = SpotTokens.themeLine + SpotTokens.menuRowGap
        let top = CGFloat(line) * pitch
        let clip = scroll.contentView
        clip.scroll(to: CGPoint(x: 0, y: max(top - clip.bounds.height / 3, 0)))
        scroll.reflectScrolledClipView(clip)
        let left = document.bounds.width - SpotTokens.themeRowPadding - cells * SpotTokens.themeCellWidth - (cells - 1) * SpotTokens.themeSpacing
        let rect = CGRect(x: left, y: top, width: SpotTokens.themeCellWidth, height: SpotTokens.themeLine)
        let flipped = document.isFlipped ? rect : CGRect(x: rect.minX, y: document.bounds.height - rect.maxY, width: rect.width, height: rect.height)
        return document.convert(flipped, to: nil)
    }

    private func colour(in view: NSView) {
        guard let well = Self.all(NSColorWell.self, in: view).first(where: { !$0.visibleRect.isEmpty && $0.isEnabled }) else { return end(with: "no colour well\n") }
        timed { time in
            well.color = NSColor(hue: (time / 2).truncatingRemainder(dividingBy: 1), saturation: 0.6, brightness: 0.8, alpha: 1)
            well.sendAction(well.action, to: well.target)
        }
    }

    private func stepper(_ editor: SpotThemeModel, in view: NSView) {
        guard let scroll = rowsScroll(in: view), cell(of: .points, in: editor, scroll: scroll) != nil else { return end(with: "no stepper\n") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let cell = self.cell(of: .points, in: editor, scroll: scroll) else { return self.end(with: "no stepper\n") }
            let stepper = NSStepper()
            stepper.controlSize = .small
            let size = stepper.fittingSize
            self.press(CGRect(x: cell.minX + SpotTokens.themeNumberWidth + SpotTokens.themeSpacing, y: cell.midY - size.height / 2, width: size.width, height: size.height))
        }
    }

    private func press(_ stepper: CGRect) {
        let up = CGPoint(x: stepper.midX, y: stepper.minY + stepper.height * 0.75)
        let down = CGPoint(x: stepper.midX, y: stepper.minY + stepper.height * 0.25)
        let at = { (index: Int) in index % 2 == 0 ? up : down }
        let gap = 0.15
        var pressed = -1
        var isDown = false
        timed { time in
            let index = Int(time / gap)
            if index != pressed {
                if isDown { self.post(.leftMouseUp, at: at(pressed)) }
                pressed = index
                isDown = true
                self.post(.leftMouseDown, at: at(index))
            } else if isDown, time - Double(index) * gap > 0.03 {
                isDown = false
                self.post(.leftMouseUp, at: at(index))
            }
            self.notes = ["presses \(pressed + 1)"]
        }
    }

    private func drag(_ editor: SpotThemeModel, in view: NSView) {
        let scale = SpotTokens.stageScale
        let width = view.bounds.width
        let left = width - SpotTokens.themePadding - SpotTokens.themeStageWidth + (SpotTokens.themeStageWidth - SpotTokens.panelWidth * scale) / 2
        let top = view.safeAreaInsets.top + SpotTokens.themePadding + SpotTokens.themeLine
        let marks = editor.stage.themeMarks()
        guard let mark = marks.all.first(where: { if case .band = $0.shape { return $0.hit.height < $0.hit.width } else { return false } }) else {
            return end(with: "no mark\n")
        }
        let inStage = CGPoint(x: mark.hit.midX, y: mark.hit.midY)
        let place = CGPoint(x: left + inStage.x * scale, y: view.bounds.height - (top + inStage.y * scale))
        editor.point(at: inStage)
        guard editor.lit != nil else { return end(with: "no lit mark at \(inStage)\n") }
        let reach = 30.0
        var begun = false
        timed { time in
            if !begun {
                begun = true
                return self.post(.leftMouseDown, at: place)
            }
            let share = sin(time * 2 * .pi / 1.5)
            let point = CGPoint(x: place.x, y: place.y - reach * share)
            if time > self.seconds - 0.05 { return self.post(.leftMouseUp, at: point) }
            self.post(.leftMouseDragged, at: point)
            self.notes = ["mark \(mark.key.key) tip \(editor.tip ?? "none")"]
        }
    }

    private func post(_ type: NSEvent.EventType, at point: CGPoint) {
        guard let window, let event = NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1
        ) else { return }
        NSApp.postEvent(event, atStart: false)
    }

    private func end(with text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.link?.invalidate()
            self.finish(self.report() + "theme changes \(self.changes)\n" + self.notes.joined(separator: "\n") + "\n" + text + "\n")
        }
    }

    private func report() -> String {
        guard let start else { return "no frames\n" }
        let gaps = zip(frames.dropFirst(), frames).filter { $0.1 >= start && $0.0 <= start + seconds }.map { ($0.0 - $0.1) * 1000 }
        guard !gaps.isEmpty else { return "no frames\n" }
        let budget = 1000 / Double(window?.screen?.maximumFramesPerSecond ?? 120)
        let dropped = gaps.map { max(Int(($0 / budget).rounded()) - 1, 0) }.reduce(0, +)
        let sorted = gaps.sorted()
        return String(
            format: "%@ fps %.0f, p50 %.1f ms, p99 %.1f ms, worst %.1f ms, frames %d, dropped %d\n",
            motion, Double(gaps.count) / (gaps.reduce(0, +) / 1000), sorted[sorted.count / 2], sorted[min(Int(Double(sorted.count) * 0.99), sorted.count - 1)],
            sorted.last ?? 0, gaps.count, dropped
        )
    }

    private static func all<View: NSView>(_ type: View.Type, in view: NSView) -> [View] {
        ((view as? View).map { [$0] } ?? []) + view.subviews.flatMap { all(type, in: $0) }
    }

}
#endif
