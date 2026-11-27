import AppKit
import OpenspotCore

@MainActor
enum SpotChoiceMenu {
    static func popUp(options: [SpotPart.Option], value: String?, over rect: CGRect, choose: (String) -> Void) {
        guard let window = NSApp.currentEvent?.window ?? NSApp.keyWindow, let content = window.contentView else { return }
        let cell = NSPopUpButtonCell(textCell: "", pullsDown: false)
        cell.autoenablesItems = false
        for option in options {
            cell.addItem(withTitle: option.title)
            cell.lastItem?.representedObject = option.id
            cell.lastItem?.image = image(of: option.icon)
        }
        let chosen = options.firstIndex { $0.id == value } ?? 0
        cell.selectItem(at: chosen)
        let frame = NSRect(x: rect.minX, y: content.isFlipped ? rect.minY : content.bounds.height - rect.maxY, width: rect.width, height: rect.height)
        cell.performClick(withFrame: frame, in: content)
        guard cell.indexOfSelectedItem != chosen, let id = cell.selectedItem?.representedObject as? String else { return }
        choose(id)
    }

    private static func image(of icon: Icon?) -> NSImage? {
        switch icon {
        case .file(let path):
            guard let picture = SpotIconStore.shared.cachedNative(path, pixels: SpotTokens.choiceMenuPixels) else { return nil }
            let side = SpotTokens.choiceMenuIcon
            let whole = side / IconBody.share
            let frame = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: (side - whole) / 2, dy: (side - whole) / 2)
            return NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
                NSGraphicsContext.current?.cgContext.draw(picture, in: frame)
                return true
            }
        case .image(let path):
            guard let picture = SpotIconStore.shared.cached(.image(path)) else { return nil }
            let side = SpotTokens.choiceMenuIcon
            return NSImage(cgImage: picture, size: NSSize(width: side, height: side))
        case .symbol(let name):
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        default:
            return nil
        }
    }
}
