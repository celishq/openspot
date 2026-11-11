import Foundation

/// What the Mac tells the core through the frameworks that Core does not import: the wake of the Mac, the app that comes to
/// the front, the wake of the screen, and the count of changes of the clipboard (B2). A test gives a source of its own.
@MainActor
public protocol EventSource: AnyObject {
    /// Calls `heard` with `wake`, `app.front` and `screen.wake` each time one occurs.
    func listen(_ heard: @escaping @MainActor (SpotEvent) -> Void)
    /// The count of changes of the clipboard, which each copy makes larger.
    var clipboardCount: Int { get }
}
