import AppKit

@MainActor
final class NextFrame: NSObject {
    private var waiting: [@MainActor () -> Void] = []
    private var link: CADisplayLink?

    func run(in view: NSView?, _ body: @escaping @MainActor () -> Void) {
        guard let view, view.window?.isVisible == true else { return DispatchQueue.main.async(execute: body) }
        waiting.append(body)
        if link == nil {
            let link = view.displayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            self.link = link
        }
        link?.isPaused = false
    }

    @objc private func tick() {
        link?.isPaused = true
        let bodies = waiting
        waiting = []
        bodies.forEach { $0() }
    }
}
