import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class MenuBarMarkItem {
    let item: NSStatusItem
    private let host: MenuBarHost<SpotMenuBarMarkView>
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
        if item.length != width { item.length = width }
        host.frame = NSRect(x: 0, y: 0, width: width, height: item.button?.bounds.height ?? 0)
        item.button?.toolTip = mark.summary
        item.button?.setAccessibilityLabel(mark.summary)
    }
}
