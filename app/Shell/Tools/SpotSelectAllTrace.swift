#if OPENSPOT_TOOLS
import OpenspotCore
import AppKit
import QuartzCore

@MainActor
final class SpotSelectAllTrace: NSObject {
    nonisolated(unsafe) static var current: SpotSelectAllTrace?
    private let model: SpotsModel
    let panel: NSPanel
    private let finish: (String) -> Void
    private var lines: [String] = []
    private var frames = 0
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0
    private var turnStart: CFTimeInterval = 0
    var turnHadKey = false
    var depth: [String] = []
    private var keyFrame = 0
    private var selectTurnEnd: CFTimeInterval?
    private var observer: CFRunLoopObserver?
    var layouts = 0
    var inLayout = false
    var stacks = 0

    init(model: SpotsModel, panel: NSPanel, finish: @escaping (String) -> Void) {
        self.model = model
        self.panel = panel
        self.finish = finish
    }

    func run() {
        Self.current = self
        hook()
        let link = panel.contentView!.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        start = CACurrentMediaTime()
        watchTurns()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                let late = (CACurrentMediaTime() - event.timestamp) * 1000
                self.turnHadKey = true
                self.keyFrame = self.frames
                self.log("event \(Self.name(event)) key \(self.panel.isKeyWindow) shown \(self.model.isShown) picked up \(String(format: "%.1f", late)) ms after it was posted, hint takes \(self.model.hintTakes)")
            }
            return event
        }
        log("first responder \(type(of: panel.firstResponder as Any)), key \(panel.isKeyWindow), text '\(model.searchText)'")
        let plan: [(String, [Step])] = (0..<4).flatMap { index -> [(String, [Step])] in
            let code: CGKeyCode = index % 2 == 0 ? 11 : 8
            return [("pause", [.type(code), .wait(0.6), .mark("second letter"), .type(code), .wait(0.6), .selectAll, .wait(0.6)]), ("burst", [.type(code), .selectAll, .wait(0.6)])]
        }
        play(plan.flatMap { name, steps in [.mark(name), .clear, .wait(0.6)] + steps })
    }

    enum Step { case type(CGKeyCode), selectAll, wait(Double), clear, mark(String) }

    private func play(_ steps: [Step]) {
        guard let step = steps.first else {
            return DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.link?.invalidate(); self.finish(self.lines.joined(separator: "\n") + "\n") }
        }
        let rest = Array(steps.dropFirst())
        switch step {
        case .type(let code): post(code, flags: [])
        case .selectAll: post(0, flags: .maskCommand)
        case .clear: model.search("")
        case .mark(let name): log("--- \(name)")
        case .wait(let seconds): return DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { self.play(rest) }
        }
        play(rest)
    }

    private func post(_ code: CGKeyCode, flags: CGEventFlags) {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
            event?.flags = flags
            event?.postToPid(getpid())
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        frames += 1
        if let end = selectTurnEnd {
            selectTurnEnd = nil
            log("  first frame after the select's turn ended: frame +\(frames - keyFrame) from the key, \(String(format: "%.1f", (link.timestamp - end) * 1000)) ms after")
        }
    }

    private func watchTurns() {
        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.afterWaiting.rawValue | CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { _, activity in
            MainActor.assumeIsolated {
                let now = CACurrentMediaTime()
                if activity == .afterWaiting {
                    self.turnStart = now
                    self.turnHadKey = false
                    self.layouts = 0
                } else if self.turnHadKey || now - self.turnStart > 0.006 {
                    self.log("  turn \(String(format: "%.1f", (now - self.turnStart) * 1000)) ms\(self.turnHadKey ? " (held a key)" : ""), \(self.layouts) panel layouts, frame +\(self.frames - self.keyFrame)")
                }
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
    }

    func log(_ text: String) {
        lines.append(String(format: "%8.1f f%-4d ", (CACurrentMediaTime() - start) * 1000, frames) + String(repeating: "  ", count: depth.count) + text)
    }

    func around<T>(_ name: String, detail: String = "", _ work: () -> T) -> T {
        let before = CACurrentMediaTime()
        let hints = model.hintTakes
        log("> \(name)\(detail)")
        depth.append(name)
        let result = work()
        depth.removeLast()
        log("< \(name) \(String(format: "%.2f", (CACurrentMediaTime() - before) * 1000)) ms\(model.hintTakes != hints ? ", hint worked out \(model.hintTakes - hints)x" : "") -> \(result)")
        if name == "selectAll" { selectTurnEnd = CACurrentMediaTime() }
        return result
    }

    private static func name(_ event: NSEvent) -> String {
        (event.modifierFlags.contains(.command) ? "⌘" : "") + (event.charactersIgnoringModifiers ?? "?")
    }

    private func hook() {
        typealias Layout = @convention(c) (NSView, Selector) -> Void
        if let host = panel.contentView, let method = class_getInstanceMethod(type(of: host), #selector(NSView.layout)) {
            let original = unsafeBitCast(method_getImplementation(method), to: Layout.self)
            let block: @convention(block) (NSView) -> Void = { view in
                MainActor.assumeIsolated {
                    if let trace = SpotSelectAllTrace.current, view === trace.panel.contentView {
                        trace.layouts += 1
                        if !trace.depth.isEmpty { trace.log("panel layout inside \(trace.depth.joined(separator: " > "))") }
                        if trace.turnHadKey { trace.log("  layout \(trace.layouts) begins") }
                        trace.inLayout = true
                        original(view, #selector(NSView.layout))
                        trace.inLayout = false
                        if trace.turnHadKey { trace.log("  layout \(trace.layouts) ends") }
                        return
                    }
                    original(view, #selector(NSView.layout))
                }
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
        }
        typealias SetNeeds = @convention(c) (NSView, Selector, Bool) -> Void
        let needsSelector = NSSelectorFromString("setNeedsLayout:")
        if let method = class_getInstanceMethod(NSView.self, needsSelector) {
            let original = unsafeBitCast(method_getImplementation(method), to: SetNeeds.self)
            let block: @convention(block) (NSView, Bool) -> Void = { view, flag in
                MainActor.assumeIsolated {
                    if flag, let trace = SpotSelectAllTrace.current, trace.turnHadKey, view === trace.panel.contentView, !view.needsLayout {
                        let stack = SpotSelectAllTrace.names(of: Thread.callStackReturnAddresses)
                        let cause = stack.contains("configureRenderingSurface") ? "text view adds a fragment subview" : stack.contains("requestUpdate") ? "host requestUpdate block" : stack.contains("setRootView") ? "setRootView" : stack.contains("sendEvent") ? "inside sendEvent" : "other"
                        trace.log("  setNeedsLayout on panel root, after layout \(trace.layouts), inLayout \(trace.inLayout): \(cause)")
                        if cause == "other", trace.stacks < 3 {
                            trace.stacks += 1
                            for line in Thread.callStackSymbols.prefix(60) { trace.log("    " + line) }
                        }
                    }
                    original(view, needsSelector, flag)
                }
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
        }
        swizzle(SpotsPanel.self, #selector(NSWindow.sendEvent(_:))) { original in
            { (window: NSWindow, event: NSEvent) in
                guard event.type == .keyDown, let trace = SpotSelectAllTrace.current else { return original(window, #selector(NSWindow.sendEvent(_:)), event) }
                trace.around("SpotsPanel.sendEvent", detail: " \(SpotSelectAllTrace.name(event))") { original(window, #selector(NSWindow.sendEvent(_:)), event) }
            }
        }
        swizzleBool(NSWindow.self, #selector(NSWindow.performKeyEquivalent(with:)), label: "NSWindow.performKeyEquivalent")
        swizzleBool(NSView.self, #selector(NSView.performKeyEquivalent(with:)), label: "contentView.performKeyEquivalent", onlyContentView: true)
        swizzleBool(NSMenu.self, #selector(NSMenu.performKeyEquivalent(with:)), label: "NSMenu.performKeyEquivalent")
        typealias Select = @convention(c) (NSTextView, Selector, Any?) -> Void
        let selector = #selector(NSTextView.selectAll(_:))
        guard let method = class_getInstanceMethod(NSTextView.self, selector) else { return }
        let original = unsafeBitCast(method_getImplementation(method), to: Select.self)
        let block: @convention(block) (NSTextView, Any?) -> Void = { text, sender in
            MainActor.assumeIsolated {
                guard let trace = SpotSelectAllTrace.current else { return original(text, selector, sender) }
                trace.around("selectAll", detail: " by \(type(of: sender as Any))") { original(text, selector, sender) }
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private typealias Send = @convention(c) (NSWindow, Selector, NSEvent) -> Void

    private func swizzle(_ type: AnyClass, _ selector: Selector, _ make: (@escaping Send) -> (NSWindow, NSEvent) -> Void) {
        guard let method = class_getInstanceMethod(type, selector) else { return }
        let original = unsafeBitCast(method_getImplementation(method), to: Send.self)
        let wrapped = make(original)
        let block: @convention(block) (NSWindow, NSEvent) -> Void = { window, event in MainActor.assumeIsolated { wrapped(window, event) } }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private func swizzleBool(_ type: AnyClass, _ selector: Selector, label: String, onlyContentView: Bool = false) {
        typealias Perform = @convention(c) (NSObject, Selector, NSEvent) -> Bool
        guard let method = class_getInstanceMethod(type, selector) else { return }
        let original = unsafeBitCast(method_getImplementation(method), to: Perform.self)
        let block: @convention(block) (NSObject, NSEvent) -> Bool = { object, event in
            MainActor.assumeIsolated {
                guard let trace = SpotSelectAllTrace.current, event.type == .keyDown else { return original(object, selector, event) }
                if onlyContentView, (object as? NSView)?.window?.contentView !== object { return original(object, selector, event) }
                if !onlyContentView, let window = object as? NSWindow, !(window is SpotsPanel) { return original(object, selector, event) }
                return trace.around(label, detail: onlyContentView ? " (\(Self.count(object as! NSView)) views)" : "") { original(object, selector, event) }
            }
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func names(of addresses: [NSNumber]) -> String {
        addresses.compactMap { address in
            var info = Dl_info()
            guard dladdr(UnsafeRawPointer(bitPattern: address.uintValue), &info) != 0, let name = info.dli_sname else { return nil }
            return String(cString: name)
        }.joined(separator: "\n")
    }

    private static func count(_ view: NSView) -> Int {
        1 + view.subviews.reduce(0) { $0 + count($1) }
    }
}
#endif
