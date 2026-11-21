import AppKit
import OpenspotCore

extension NSWindow {
    func placeCaretAtEnd() {
        guard let text = firstResponder as? NSTextView else { return }
        let end = NSRange(location: (text.string as NSString).length, length: 0)
        if text.selectedRange() != end { text.setSelectedRange(end) }
    }

    func textKeeps(_ key: ActionKey) -> Bool {
        guard let text = firstResponder as? NSTextView else { return false }
        if text.hasMarkedText() { return true }
        guard key == ActionKey(name: "up") || key == ActionKey(name: "down"), text.isEditable, !text.isFieldEditor else { return false }
        let line = { (location: Int) in text.firstRect(forCharacterRange: NSRange(location: location, length: 0), actualRange: nil).midY }
        let caret = line(text.selectedRange().location)
        let edge = line(key.name == "up" ? 0 : (text.string as NSString).length)
        return abs(caret - edge) > 1
    }
}
