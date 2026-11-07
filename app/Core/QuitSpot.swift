import Foundation

/// The Quit spot, which ships with the app. Search finds it, and a press ends the app.
public struct QuitSpot: Equatable, Sendable {
    private let quit: @Sendable () async -> Void

    public init(quit: @escaping @Sendable () async -> Void) {
        self.quit = quit
    }

    /// Answers one call with the text a script would print.
    func answer() async -> String {
        await quit()
        return ""
    }

    public static func == (left: QuitSpot, right: QuitSpot) -> Bool {
        true
    }
}
