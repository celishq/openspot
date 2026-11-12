import AppKit
import OpenspotCore

/// The host of a model with no window, such as one that draws a card to a picture: it shows nothing and tells nothing,
/// and gives the spots that ship with the app.
@MainActor
final class SpotQuietHost: SpotsHost {
    /// The one quiet host, which lives as long as the process, because a model holds its host unowned.
    static let shared = SpotQuietHost()

    nonisolated deinit {}

    func dismiss() {}
    func show() {}
    func present() {}
    func notify(_ text: String) {}
    func notify(_ text: String, fix: URL) {}
    func confirm(_ text: String) {}
    func applyConfig(_ config: Config) {}
    func setEntryKey(on isOn: Bool) {}
    func hold(_ keys: [GlobalKey]) {}
    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void) {}
    func float(_ entry: SpotsModel.Entry, followsDrag: Bool) {}
    func land(_ id: String) {}
    var isPointerOverDrop: Bool { false }
    var draggedPaths: [String] { [] }
    var isMouseDown: Bool { false }
    var pastedPaths: [String] { [] }
    func copy(_ file: URL) {}
    func prepare(_ items: [SpotItem], glyphs: [String]) async {}

    func agentPrompt(for folder: URL) -> AgentPrompt {
        AgentPrompt(folder: folder, guide: Bundle.main.url(forResource: "GUIDE", withExtension: "md") ?? folder, app: AgentPrompt.command(of: Bundle.main.executablePath ?? ""))
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        body()
        completion()
    }
}
