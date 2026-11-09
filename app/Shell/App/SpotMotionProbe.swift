import OpenspotCore
import AppKit
import QuartzCore

/// A run that opens and closes the sheet of one spot again and again, or with `OPENSPOT_ACTION` moves down its rows, types
/// in its search or picks the row `OPENSPOT_ROW`, and writes the time of each frame to a file. `scripts/motion-perf.sh` starts it with `OPENSPOT_PROBE`.
/// The panel stays almost clear, takes no focus and no clicks, unless `OPENSPOT_SEEN` asks for a picture.
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
    private let action: String?
    /// The row that the `pick` action picks.
    private let row: String?
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
        action = environment["OPENSPOT_ACTION"].flatMap { $0.isEmpty ? nil : $0 }
        row = environment["OPENSPOT_ROW"]
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
