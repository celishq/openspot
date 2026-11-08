import AppKit
import Carbon.HIToolbox
import OpenspotCore

/// System-wide keys, which need no permission from the person.
enum HotKey {
    struct Registration {
        fileprivate let id: UInt32
        fileprivate let reference: EventHotKeyRef
    }

    nonisolated(unsafe) private static var actions: [UInt32: () -> Void] = [:]
    nonisolated(unsafe) private static var nextID: UInt32 = 1
    nonisolated(unsafe) private static var isInstalled = false

    static func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Registration? {
        installHandler()
        let id = nextID
        nextID += 1
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F505348), id: id)
        guard RegisterEventHotKey(shortcut.code, carbonModifiers(of: shortcut), hotKeyID, GetApplicationEventTarget(), 0, &reference) == noErr,
              let reference else { return nil }
        actions[id] = action
        return Registration(id: id, reference: reference)
    }

    static func unregister(_ registration: Registration) {
        UnregisterEventHotKey(registration.reference)
        actions[registration.id] = nil
    }

    private static func carbonModifiers(of shortcut: Shortcut) -> UInt32 {
        var modifiers = 0
        if shortcut.modifiers.contains(.command) { modifiers |= cmdKey }
        if shortcut.modifiers.contains(.control) { modifiers |= controlKey }
        if shortcut.modifiers.contains(.option) { modifiers |= optionKey }
        if shortcut.modifiers.contains(.shift) { modifiers |= shiftKey }
        return UInt32(modifiers)
    }

    private static func installHandler() {
        guard !isInstalled else { return }
        isInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            HotKey.actions[id.id]?()
            return noErr
        }, 1, &spec, nil, nil)
    }
}
