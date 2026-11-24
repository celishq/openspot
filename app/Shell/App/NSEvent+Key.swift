import AppKit
import Carbon.HIToolbox
import OpenspotCore

extension NSEvent {
    @MainActor var actionKey: ActionKey? {
        let isCommand = modifierFlags.contains(.command)
        let isShift = modifierFlags.contains(.shift)
        let name: String
        switch Int(keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter: name = "return"
        case kVK_Delete: name = "backspace"
        case kVK_Escape: name = "escape"
        case kVK_UpArrow: name = "up"
        case kVK_DownArrow: name = "down"
        case kVK_LeftArrow: name = "left"
        case kVK_RightArrow: name = "right"
        case kVK_Tab: name = "tab"
        default:
            guard let typed = charactersIgnoringModifiers else { return nil }
            return ActionKey(typed: typed, code: keyCode, isCommand: isCommand, isShift: isShift, latin: SpotKeyLayouts.latin)
        }
        return ActionKey(name: name, isCommand: isCommand, isShift: isShift)
    }

    var keyModifiers: Shortcut.Modifiers {
        Shortcut.Modifiers(modifierFlags)
    }
}

extension Shortcut.Modifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.command) { insert(.command) }
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
    }
}
