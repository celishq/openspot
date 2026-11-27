import Foundation

@MainActor
public protocol SpotsHost: AnyObject {
    func dismiss()
    func show()
    func present()
    func takeFocus()
    func toast(_ note: ToastNote, of spot: String)
    func open(_ url: URL)
    func applyConfig(_ config: Config)
    func paint(_ colours: Theme.Colours)
    func layOut(_ layout: Theme.Layout)
    func widen()
    func arrange(_ isOn: Bool)
    func setEntryKey(on isOn: Bool)
    func hold(_ keys: [GlobalKey])
    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void)
    func showSubmenu(beside row: CGRect, of menu: CGRect)
    func hideSubmenu()
    func hasRoomRight(of sheet: CGRect, for width: CGFloat) -> Bool
    func reach(_ rect: CGRect?)
    func readAhead(_ looks: [Peek.Look])
    func float(_ entry: SpotsModel.Entry, followsDrag: Bool)
    func land(_ id: String)
    func window(_ entry: SpotsModel.Entry)
    func focusWindow(_ id: String)
    func showSettings()
    func focusSettings()
    var isPointerOverDrop: Bool { get }
    var isPointerOverWindow: Bool { get }
    var draggedPaths: [String] { get }
    var isMouseDown: Bool { get }
    var pastedPaths: [String] { get }
    var frontApp: FrontApp? { get }
    func copy(_ file: URL)
    func prepare(_ items: [SpotItem], glyphs: [String]) async
    func prepareCards(glyphs: [String])
    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void)
    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void, removal: @escaping @MainActor () -> Void)
    func snap(_ body: () -> Void)
    func join(_ body: () -> Void)
    func nextFrame(_ body: @escaping @MainActor () -> Void)
    func allows(_ reason: String) async -> Bool
    func openStore(file: URL)
}

extension SpotsHost {
    public func focusWindow(_ id: String) {}

    public func showSettings() {}

    public func focusSettings() {}

    public func toast(_ note: ToastNote, of spot: String) {}

    public func arrange(_ isOn: Bool) {}

    public func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void, removal: @escaping @MainActor () -> Void) {
        change(motion, body) {
            completion()
            removal()
        }
    }

    public func snap(_ body: () -> Void) {
        change(nil, body, completion: {})
    }

    public func join(_ body: () -> Void) {
        snap(body)
    }

    public var frontApp: FrontApp? {
        nil
    }

    public func nextFrame(_ body: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async(execute: body)
    }

    public func allows(_ reason: String) async -> Bool {
        true
    }

    public func openStore(file: URL) {}

    public func readAhead(_ looks: [Peek.Look]) {}
}
