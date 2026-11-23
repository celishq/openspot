import Foundation
@testable import OpenspotCore

@MainActor
final class FakeHost: SpotsHost {
    var dismissals = 0
    var edgeChanges: [(motion: PanelMotion?, edges: FlowEdges, rows: [String])] = []
    var shows = 0
    var notes: [String] = []
    var confirms: [String] = []
    var isPointerOverDrop = false
    var isPointerOverWindow = false
    var draggedPaths: [String] = []
    var isMouseDown = false
    var pastedPaths: [String] = []
    var motions: [PanelMotion?] = []
    var floats: [String] = []
    var landings: [String] = []
    var windows: [String] = []
    var phases: [SheetTransition.Phase] = []
    var openings: [String?] = []
    var app = "/Apps/Openspot"
    var prepared: [SpotItem] = []
    var glyphLists: [[String]] = []
    var cardGlyphs: [[String]] = []
    var heldEnds: [@MainActor () -> Void]?
    var heldRemovals: [@MainActor () -> Void]?
    weak var model: SpotsModel?

    nonisolated deinit {}


    func dismiss() {
        dismissals += 1
        model?.panelWillHide()
        model?.panelDidHide()
    }

    func show() {
        shows += 1
        model?.panelWillShow()
    }

    var presents = 0
    var focusTakes = 0

    func takeFocus() {
        focusTakes += 1
    }
    var heldDuringAsks: [Bool] = []

    func present() {
        presents += 1
    }

    var allowsActs = true
    var asked: [String] = []

    func allows(_ reason: String) async -> Bool {
        heldDuringAsks.append(model?.holdsFocus ?? false)
        asked.append(reason)
        return allowsActs
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

    func applyConfig(_ config: Config) {
        if let key = config.panelKey { model?.entryKey = key }
    }

    var paints: [Theme.Colours] = []
    var layOuts: [Theme.Layout] = []

    func paint(_ look: Theme.Colours) {
        paints.append(look)
    }

    func layOut(_ layout: Theme.Layout) {
        layOuts.append(layout)
    }

    var entryKeyIsOn = true

    func setEntryKey(on isOn: Bool) {
        entryKeyIsOn = isOn
    }

    var held: [[GlobalKey]] = []

    func hold(_ keys: [GlobalKey]) {
        held.append(keys)
    }

    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void) {}

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
        AgentPrompt(folder: folder, guide: folder.appendingPathComponent("DOCS.md"), app: app)
    }

    private(set) var isChanging = false

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        motions.append(motion)
        isChanging = true
        body()
        isChanging = false
        if let edges = model?.flowEdges, edges != edgeChanges.last?.edges { edgeChanges.append((motion, edges, model?.openItems?.shown.map(\.title) ?? [])) }
        if let phase = model?.transition.phase { phases.append(phase) }
        openings.append(model?.runs.opening.moving)
        if heldEnds != nil { heldEnds?.append(completion) } else { completion() }
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void, removal: @escaping @MainActor () -> Void) {
        change(motion, body) { [weak self] in
            completion()
            if self?.heldRemovals != nil { self?.heldRemovals?.append(removal) } else { removal() }
        }
    }
}
