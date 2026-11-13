import AppKit
import OpenspotCore
import SwiftUI

/// A menu bar item that draws a mark, as wide as the mark.
@MainActor
final class MenuBarMarkItem {
    let item: NSStatusItem
    private let host: MenuBarHost<SpotMenuBarMarkView>
    /// The mark it draws, so that a mark that did not change is not drawn again.
    private var mark: MenuBarMark?

    init(item: NSStatusItem, mark: MenuBarMark) {
        self.item = item
        host = MenuBarHost(rootView: SpotMenuBarMarkView(mark: mark))
        host.sizingOptions = [.intrinsicContentSize]
        host.autoresizingMask = [.width, .height]
        item.button?.addSubview(host)
        draw(mark)
    }

    func draw(_ mark: MenuBarMark) {
        guard self.mark != mark else { return }
        self.mark = mark
        host.rootView = SpotMenuBarMarkView(mark: mark)
        let width = ceil(host.fittingSize.width)
        item.length = width
        host.frame = NSRect(x: 0, y: 0, width: width, height: item.button?.bounds.height ?? 0)
        item.button?.toolTip = mark.summary
        item.button?.setAccessibilityLabel(mark.summary)
    }

    /// Takes the mark out of the item, and leaves the item to its owner.
    func remove() {
        host.removeFromSuperview()
    }
}
