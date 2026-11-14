import Foundation

/// What the panel's model asks of the app around it: its windows, its toasts, its keys, the clipboard, the drag, the icons,
/// the spots that ship with it, and the motion of each change. A test gives a host of its own.
@MainActor
public protocol SpotsHost: AnyObject {
    /// Hides the panel, and gives the focus back to the app that was in front, unless another app took it since.
    func dismiss()
    /// Shows the panel when it is hidden or warming.
    func show()
    /// Shows the panel for a drag: the front app stays in front, and the panel takes no focus.
    func showForDrag()
    /// Shows the panel and makes it key, as a review or a first launch does.
    func present()
    /// Makes the shown panel key again, with none of the steps of a show.
    func takeFocus()
    func notify(_ text: String)
    func notify(_ text: String, fix: URL)
    func confirm(_ text: String)
    /// Shows a toast with the work mark, which stays until the next toast.
    func work(_ text: String)
    /// Takes what the config file asks for, such as the key that opens the panel.
    func applyConfig(_ config: Config)
    func setEntryKey(on isOn: Bool)
    func hold(_ keys: [GlobalKey])
    func chooseFiles(for spot: Spot, then take: @escaping ([String]) -> Void)
    /// Shows the submenu of the open actions menu in a window of its own beside the menu, level with its row. Both rects are
    /// in the panel's space.
    func showSubmenu(beside row: CGRect, of menu: CGRect)
    func hideSubmenu()
    /// Shows the float of a spot at the pointer, or brings its float there when it shows (W4, W6). During a drag it takes no
    /// focus, so that the drag goes on (W5).
    func float(_ entry: SpotsModel.Entry, followsDrag: Bool)
    /// Closes the float or the window of a spot, when it shows.
    func land(_ id: String)
    /// Shows the sheet of a spot in a window of its own, or brings its window to the front when it shows.
    func window(_ entry: SpotsModel.Entry)
    /// Whether the pointer lies on the panel or the menu bar item.
    var isPointerOverDrop: Bool { get }
    /// The files of the drag in progress.
    var draggedPaths: [String] { get }
    /// Whether the left mouse button is down, as it is through a drag.
    var isMouseDown: Bool { get }
    /// The files on the clipboard.
    var pastedPaths: [String] { get }
    /// Puts a file on the clipboard.
    func copy(_ file: URL)
    /// Makes a list's pictures ready: draws the icons of these rows ahead of their first frame, and draws the colour
    /// glyphs of the whole list once, so that its rows find their pictures with no drawing in the app. No glyphs leave the
    /// glyphs drawn before as they are.
    func prepare(_ items: [SpotItem], glyphs: [String]) async
    /// Draws the colour glyphs of the cards ahead, so that a card finds its glyph with no drawing on the main thread.
    func prepareCards(glyphs: [String])
    /// The prompt that asks an agent to write or fix a spot in this folder, with the `openspot` command of the app.
    func agentPrompt(for folder: URL) -> AgentPrompt
    /// Makes a change on a motion, or with none at all, and calls `completion` when its motion reaches its end.
    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void)
    /// Asks the person to prove who they are, with Touch ID or the Mac password, before an act such as showing the account
    /// words. Returns whether they did.
    func allows(_ reason: String) async -> Bool
}

extension SpotsHost {
    /// A host with no Touch ID allows each act.
    public func allows(_ reason: String) async -> Bool {
        true
    }
}
