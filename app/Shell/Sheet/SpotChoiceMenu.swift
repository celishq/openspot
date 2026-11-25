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
        }
        let chosen = options.firstIndex { $0.id == value } ?? 0
        cell.selectItem(at: chosen)
        let frame = NSRect(x: rect.minX, y: content.isFlipped ? rect.minY : content.bounds.height - rect.maxY, width: rect.width, height: rect.height)
        cell.performClick(withFrame: frame, in: content)
        guard cell.indexOfSelectedItem != chosen, let id = cell.selectedItem?.representedObject as? String else { return }
        choose(id)
    }
}
