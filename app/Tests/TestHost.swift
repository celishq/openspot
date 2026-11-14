import Foundation
@testable import OpenspotCore

/// A host that records what the model asks of the app, and makes each change at once.
@MainActor
final class TestHost: SpotsHost {
    var dismissals = 0
    /// Each offset that the content of a sheet started a slide from.
    var pushStarts: [Double] = []
    var shows = 0
    var dragShows = 0
    var notes: [String] = []
    var confirms: [String] = []
    var isPointerOverDrop = false
    var isPointerOverWindow = false
    var draggedPaths: [String] = []
    var isMouseDown = false
    var pastedPaths: [String] = []
    var motions: [PanelMotion?] = []
    /// The spots that the model floated, and the ones whose float it closed, in order.
    var floats: [String] = []
    var landings: [String] = []
    var windows: [String] = []
    /// The phase of the sheet's transition after each change.
    var phases: [SheetTransition.Phase] = []
    /// The sheet whose open motion runs, after each change.
    var openings: [String?] = []
    /// The program of the app that the prompt for an agent names.
    var app = "/Apps/Openspot"
    /// The rows whose pictures the model asked to draw ahead.
    var prepared: [SpotItem] = []
    /// The glyphs of each whole list whose pictures the model asked for.
    var glyphLists: [[String]] = []
    var cardGlyphs: [[String]] = []
    /// The ends of the motions that a test holds, to run them later. With none held, each motion ends at once.
    var heldEnds: [@MainActor () -> Void]?
    /// The model whose show and hide steps the panel runs, as the app's window does.
    weak var model: SpotsModel?

    nonisolated deinit {}


    func dismiss() {
        dismissals += 1
        model?.panelWillHide()
        model?.panelDidHide()
    }

    func showForDrag() {
        dragShows += 1
        model?.panelWillShow(holding: [])
    }

    func show() {
        shows += 1
        model?.panelWillShow(holding: [])
    }

    var presents = 0
    var focusTakes = 0

    func takeFocus() {
        focusTakes += 1
    }
    /// Whether the panel held its focus during each ask for Touch ID.
    var heldDuringAsks: [Bool] = []

    func present() {
        presents += 1
    }

    func allows(_ reason: String) async -> Bool {
        heldDuringAsks.append(model?.holdsFocus ?? false)
        return true
    }

    func notify(_ text: String) {
        notes.append(text)
    }

    func notify(_ text: String, fix: URL) {
        notes.append(text)
    }

    func confirm(_ text: String) {
        confirms.append(text)
    }

    func work(_ text: String) {
        confirms.append(text)
    }

    func applyConfig(_ config: Config) {}

    func setEntryKey(on isOn: Bool) {}

    /// The keys that the model held, at each time it held them.
    var held: [[GlobalKey]] = []

    func hold(_ keys: [GlobalKey]) {
        held.append(keys)
    }

    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void) {}

    /// The row of each submenu that showed, and nil for each hide.
    var submenus: [CGRect?] = []

    func showSubmenu(beside row: CGRect, of menu: CGRect) {
        submenus.append(row)
    }

    func hideSubmenu() {
        submenus.append(nil)
    }

    var floatsFollowingDrag: [Bool] = []

    func float(_ entry: SpotsModel.Entry, followsDrag: Bool) {
        floats.append(entry.id)
        floatsFollowingDrag.append(followsDrag)
    }

    func land(_ id: String) {
        landings.append(id)
    }

    func window(_ entry: SpotsModel.Entry) {
        if model?.isShown == true { model?.panelWillHide() }
        windows.append(entry.id)
    }

    func copy(_ file: URL) {}

    func prepare(_ items: [SpotItem], glyphs: [String]) async {
        prepared += items
        if !glyphs.isEmpty { glyphLists.append(glyphs) }
    }

    func prepareCards(glyphs: [String]) {
        cardGlyphs.append(glyphs)
    }

    func agentPrompt(for folder: URL) -> AgentPrompt {
        AgentPrompt(folder: folder, guide: folder.appendingPathComponent("GUIDE.md"), app: app)
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        motions.append(motion)
        body()
        if let offset = model?.pushOffset, offset != 0 { pushStarts.append(offset) }
        if let phase = model?.transition.phase { phases.append(phase) }
        openings.append(model?.runs.opening.moving)
        if heldEnds != nil { heldEnds?.append(completion) } else { completion() }
    }
}
