import AppKit
import OpenspotCore

@MainActor
final class SpotColorPick {
    private static let limit: TimeInterval = 25

    private let sampler = NSColorSampler()
    private var answer: CheckedContinuation<String, Never>?

    private init() {}

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
