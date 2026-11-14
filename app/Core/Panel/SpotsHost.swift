import Foundation

@MainActor
public protocol SpotsHost: AnyObject {
    func dismiss()
    func show()
    func showForDrag()
    func present()
    func takeFocus()
    func notify(_ text: String)
    func notify(_ text: String, fix: URL)
    func confirm(_ text: String)
    func work(_ text: String)
    func applyConfig(_ config: Config)
    func setEntryKey(on isOn: Bool)
    func hold(_ keys: [GlobalKey])
    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void)
    func showSubmenu(beside row: CGRect, of menu: CGRect)
    func hideSubmenu()
    func float(_ entry: SpotsModel.Entry, followsDrag: Bool)
    func land(_ id: String)
    func window(_ entry: SpotsModel.Entry)
    var isPointerOverDrop: Bool { get }
    var isPointerOverWindow: Bool { get }
    var draggedPaths: [String] { get }
    var isMouseDown: Bool { get }
    var pastedPaths: [String] { get }
    func copy(_ file: URL)
    func prepare(_ items: [SpotItem], glyphs: [String]) async
    func prepareCards(glyphs: [String])
    func agentPrompt(for folder: URL) -> AgentPrompt
    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void)
    func allows(_ reason: String) async -> Bool
}

extension SpotsHost {
    public func allows(_ reason: String) async -> Bool {
        true
    }
}
