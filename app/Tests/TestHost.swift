import Foundation
@testable import OpenspotCore

/// A host that records what the model asks of the app, and makes each change at once.
@MainActor
final class TestHost: SpotsHost {
    var dismissals = 0
    var shows = 0
    var notes: [String] = []
    var confirms: [String] = []
    var isPointerOverDrop = false
    var draggedPaths: [String] = []
    var isMouseDown = false
    var pastedPaths: [String] = []
    var motions: [PanelMotion?] = []
    /// The spots that the model floated, and the ones whose float it closed, in order.
    var floats: [String] = []
    var landings: [String] = []
    /// The phase of the sheet's transition after each change.
    var phases: [SheetTransition.Phase] = []
    /// The spots that ship with the app in this test.
    var shipped: [Spot] = []
    /// The model whose show and hide steps the panel runs, as the app's window does.
    weak var model: SpotsModel?

    nonisolated deinit {}

    func dismiss() {
        dismissals += 1
        model?.panelWillHide()
        model?.panelDidHide()
    }

    func show() {
        shows += 1
        model?.panelWillShow(holding: [])
    }

    func present() {}

    func notify(_ text: String) {
        notes.append(text)
    }

    func notify(_ text: String, fix: URL) {
        notes.append(text)
    }

    func confirm(_ text: String) {
        confirms.append(text)
    }

    func applyConfig() {}

    func setEntryKey(on isOn: Bool) {}

    func hold(_ keys: [GlobalKey]) {}

    func chooseFiles(for command: Spot, then take: @escaping ([String]) -> Void) {}

    func float(_ entry: SpotsModel.Entry, followsDrag: Bool) {
        floats.append(entry.id)
    }

    func land(_ id: String) {
        landings.append(id)
    }

    func copy(_ file: URL) {}

    func prepare(_ items: [SpotItem]) async {}

    func shippedSpots(folder: PluginFolder, config: ConfigFile, update: UpdateSpot?, offersLogin: Bool) -> [Spot] {
        shipped
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        motions.append(motion)
        body()
        if let phase = model?.transition.phase { phases.append(phase) }
        completion()
    }
}
