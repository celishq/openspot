import AppKit
import QuartzCore

/// A run that opens and closes the sheet of one spot again and again and writes the time of each frame to a file.
/// `scripts/motion-perf.sh` starts it with `OPENSPOT_PROBE`. The panel stays almost clear, takes no focus and no clicks,
/// unless `OPENSPOT_SEEN` asks for a picture.
@MainActor
final class SpotMotionProbe: NSObject {
    private let model: SpotsModel
    private let panel: NSPanel
    private let output: String
    private let spot: String?
    private let presses: Int
    private let pause: Double
    /// Whether the panel shows in full, for a picture of it.
    private let isSeen: Bool
    private var link: CADisplayLink?
    private var frames: [CFTimeInterval] = []
    private var start: CFTimeInterval = 0

    init?(model: SpotsModel, panel: NSPanel, environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let output = environment["OPENSPOT_PROBE"] else { return nil }
        self.model = model
        self.panel = panel
        self.output = output
        spot = environment["OPENSPOT_SPOT"].flatMap { $0.isEmpty ? nil : $0 }
        presses = 2 * (Int(environment["OPENSPOT_CYCLES"] ?? "") ?? 20)
        pause = Double(environment["OPENSPOT_PAUSE"] ?? "") ?? 0.15
        isSeen = environment["OPENSPOT_SEEN"] != nil
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
        let target = model.entries.first { spot == nil ? $0.kind == .widget && $0.command.opens != nil : $0.id == spot }
        guard let target, let view = panel.contentView else { return finish(with: "no spot to open\n") }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        start = CACurrentMediaTime()
        press(target.id, left: presses)
    }

    private func press(_ id: String, left: Int) {
        guard left > 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.finish(with: self.report()) }
            return
        }
        if left % 2 == 0 {
            model.press(id)
        } else {
            model.allowSheetMotion()
            model.closeList()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.press(id, left: left - 1) }
    }

    @objc private func tick(_ link: CADisplayLink) {
        frames.append(link.timestamp)
    }

    /// The frame times from the first press, in milliseconds: their spread, then each one.
    private func report() -> String {
        let gaps = zip(frames.dropFirst(), frames).filter { $0.1 >= start }.map { ($0.0 - $0.1) * 1000 }
        let sorted = gaps.sorted()
        guard !sorted.isEmpty else { return "no frames\n" }
        let budget = 1000 / Double(NSScreen.main?.maximumFramesPerSecond ?? 120)
        let at = { (share: Double) in sorted[min(Int(Double(sorted.count) * share), sorted.count - 1)] }
        let late = gaps.filter { $0 > budget * 1.05 }
        let dropped = gaps.map { max(Int(($0 / budget).rounded()) - 1, 0) }.reduce(0, +)
        let seconds = gaps.reduce(0, +) / 1000
        let head = String(
            format: "fps %.0f, p50 %.1f ms, p90 %.1f ms, p99 %.1f ms, worst %.1f ms, late %d of %d, dropped %d\n",
            Double(gaps.count) / seconds, at(0.5), at(0.9), at(0.99), sorted.last ?? 0, late.count, gaps.count, dropped
        )
        return head + gaps.map { String(format: "%.1f", $0) }.joined(separator: " ") + "\n"
    }

    private func finish(with text: String) {
        link?.invalidate()
        FileManager.default.createFile(atPath: output, contents: Data(text.utf8))
        exit(0)
    }
}
