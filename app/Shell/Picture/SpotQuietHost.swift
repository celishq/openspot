import AppKit
import OpenspotCore

@MainActor
final class SpotQuietHost: SpotsHost {
    static let shared = SpotQuietHost()

    nonisolated deinit {}

    func dismiss() {}
    func show() {}
    func present() {}
    func takeFocus() {}
    func open(_ url: URL) {}
    func applyConfig(_ config: Config) {}
    func paint(_ colours: Theme.Colours) { SpotLoadedTheme.shared.paint(colours) }
    func layOut(_ layout: Theme.Layout) { SpotLoadedTheme.shared.lay(layout) }
    func widen() { SpotLoadedTheme.shared.widen() }
    func setEntryKey(on isOn: Bool) {}
    func hold(_ keys: [GlobalKey]) {}
    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void) {}
    func showSubmenu(beside row: CGRect, of menu: CGRect) {}
    func hideSubmenu() {}
    func hasRoomRight(of sheet: CGRect, for width: CGFloat) -> Bool { true }
    func reach(_ rect: CGRect?) {}
    func float(_ entry: SpotsModel.Entry, followsDrag: Bool) {}
    func land(_ id: String) {}
    func window(_ entry: SpotsModel.Entry) {}
    var isPointerOverDrop: Bool { false }
    var isPointerOverWindow: Bool { false }
    var draggedPaths: [String] { [] }
    var isMouseDown: Bool { false }
    var pastedPaths: [String] { [] }
    func copy(_ file: URL) {}
    func prepare(_ items: [SpotItem], glyphs: [String]) async {}
    func prepareCards(glyphs: [String]) {}

    func agentPrompt(for folder: URL) -> AgentPrompt {
        AgentPrompt(folder: folder, guide: Bundle.main.url(forResource: "DOCS", withExtension: "md") ?? folder, app: AgentPrompt.command(of: Bundle.main.executablePath ?? ""))
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        body()
        completion()
    }
}
