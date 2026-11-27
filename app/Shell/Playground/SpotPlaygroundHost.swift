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
    func toast(_ note: ToastNote, of spot: String) { onNote(note.words) }
    func open(_ url: URL) {}
    func applyConfig(_ config: Config) {}
    func paint(_ colours: Theme.Colours) {}
    func layOut(_ layout: Theme.Layout) {}
    func widen() {}
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

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        body()
        completion()
    }
}
