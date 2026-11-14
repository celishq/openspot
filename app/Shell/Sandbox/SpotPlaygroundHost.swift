import AppKit
import OpenspotCore

@MainActor
final class SpotPlaygroundHost: SpotsHost {
    var onNote: (String) -> Void = { _ in }

    nonisolated deinit {}

    func dismiss() {}
    func show() {}
    func present() {}
    func takeFocus() {}
    func notify(_ text: String) { onNote(text) }
    func notify(_ text: String, fix: URL) { onNote(text) }
    func confirm(_ text: String) { onNote(text) }
    func work(_ text: String) { onNote(text) }
    func applyConfig(_ config: Config) {}
    func setEntryKey(on isOn: Bool) {}
    func hold(_ keys: [GlobalKey]) {}
    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void) {}
    func showSubmenu(beside row: CGRect, of menu: CGRect) {}
    func hideSubmenu() {}
    func float(_ entry: SpotsModel.Entry, followsDrag: Bool) {}
    func land(_ id: String) {}
    func window(_ entry: SpotsModel.Entry) {}
    func showForDrag() {}
    var isPointerOverDrop: Bool { false }
    var isPointerOverWindow: Bool { false }
    var draggedPaths: [String] { [] }
    var isMouseDown: Bool { false }
    var pastedPaths: [String] { [] }
    func copy(_ file: URL) {}
    func prepare(_ items: [SpotItem], glyphs: [String]) async {}
    func prepareCards(glyphs: [String]) {}

    func agentPrompt(for folder: URL) -> AgentPrompt {
        AgentPrompt(folder: folder, guide: Bundle.main.url(forResource: "GUIDE", withExtension: "md") ?? folder, app: AgentPrompt.command(of: Bundle.main.executablePath ?? ""))
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        body()
        completion()
    }
}
