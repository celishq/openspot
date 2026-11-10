import Foundation

/// What the panel's model asks of the app around it: its windows, its toasts, its keys, the clipboard, the drag, the icons,
/// the spots that ship with it, and the motion of each change. A test gives a host of its own.
@MainActor
public protocol SpotsHost: AnyObject {
    /// Hides the panel, and gives the focus back to the app that was in front, unless another app took it since.
    func dismiss()
    /// Shows the panel when it is hidden or warming.
    func show()
    /// Shows the panel and makes it key, as a review or a first launch does.
    func present()
    func notify(_ text: String)
    func notify(_ text: String, fix: URL)
    func confirm(_ text: String)
    /// Takes what the config file asks for, such as the key that opens the panel.
    func applyConfig()
    func setEntryKey(on isOn: Bool)
    func hold(_ keys: [GlobalKey])
    func chooseFiles(for command: Spot, then take: @escaping ([String]) -> Void)
    /// Shows the float of a spot at the pointer, or brings its float there when it shows (W4, W6).
    func float(_ entry: SpotsModel.Entry)
    /// Closes the float of a spot, when it shows.
    func land(_ id: String)
    /// Whether the pointer lies on the panel or the menu bar item.
    var isPointerOverDrop: Bool { get }
    /// The files of the drag in progress.
    var draggedPaths: [String] { get }
    var isMouseDown: Bool { get }
    /// The files on the clipboard.
    var pastedPaths: [String] { get }
    /// Puts a file on the clipboard.
    func copy(_ file: URL)
    /// Draws the icons of these rows ahead of their first frame.
    func prepare(_ items: [SpotItem]) async
    /// The spots that ship with the app, as its bundle gives them.
    func shippedSpots(folder: PluginFolder, config: ConfigFile, update: UpdateSpot?, offersLogin: Bool) -> [Spot]
    /// Makes a change on a motion, or with none at all, and calls `completion` when its motion has ended.
    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void)
}
