import AppKit
import OpenspotCore

/// The macOS colour sampler for a script. It gives the picked colour, and nothing on a cancel.
@MainActor
final class SpotColorPick {
    private static let limit: TimeInterval = 25

    private let sampler = NSColorSampler()
    private var answer: CheckedContinuation<String, Never>?

    private init() {}

    /// The picked colour on a line, or nothing on a cancel or once its time is up, before the action of its script times
    /// out. It waits on the main thread without blocking it.
    static func pick() async -> String {
        let pick = SpotColorPick()
        return await withCheckedContinuation { answer in
            pick.answer = answer
            pick.sampler.show { color in
                let picked = color?.usingColorSpace(.sRGB).map { HexColor(red: $0.redComponent, green: $0.greenComponent, blue: $0.blueComponent).text + "\n" }
                MainActor.assumeIsolated { pick.finish(picked ?? "") }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + limit) { pick.finish("") }
        }
    }

    private func finish(_ text: String) {
        answer?.resume(returning: text)
        answer = nil
    }
}
