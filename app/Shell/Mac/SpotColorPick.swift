import AppKit
import OpenspotCore

/// The macOS colour sampler for a script. It prints the picked colour, and prints nothing on a cancel.
@MainActor
enum SpotColorPick {
    private static let limit: TimeInterval = 25

    /// Runs until a pick or a cancel, and stops by itself before the action of its script times out.
    static func run() -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let sampler = NSColorSampler()
        sampler.show { color in
            if let color = color?.usingColorSpace(.sRGB) {
                print(HexColor(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent).text)
            }
            exit(0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + limit) { exit(0) }
        app.run()
        exit(0)
    }
}
