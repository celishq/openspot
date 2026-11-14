import AppKit
import OpenspotCore

@MainActor
final class SpotChoiceMenu: NSObject {
    private let choose: (String) -> Void

    private init(choose: @escaping (String) -> Void) {
        self.choose = choose
    }

    static func popUp(options: [SpotPart.Option], value: String?, under rect: CGRect, choose: @escaping (String) -> Void) {
        guard let window = NSApp.keyWindow, let content = window.contentView else { return }
        let target = SpotChoiceMenu(choose: choose)
        let menu = NSMenu()
        menu.autoenablesItems = false
        for option in options {
            let item = NSMenuItem(title: option.title, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = target
            item.representedObject = option.id
            item.state = option.id == value ? .on : .off
            menu.addItem(item)
        }
        let corner = NSPoint(x: rect.minX, y: content.isFlipped ? rect.maxY : content.bounds.height - rect.maxY)
        let point = window.convertPoint(toScreen: content.convert(corner, to: nil))
        withExtendedLifetime(target) { _ = menu.popUp(positioning: nil, at: point, in: nil) }
    }

    @objc private func pick(_ item: NSMenuItem) {
        if let id = item.representedObject as? String { choose(id) }
    }
}
