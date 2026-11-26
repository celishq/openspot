import AppKit
import Carbon.HIToolbox
import OpenspotCore

enum HotKey {
    struct Registration {
        fileprivate let id: UInt32
    }

    private struct Held {
        let shortcut: Shortcut
        let action: () -> Void
        var reference: EventHotKeyRef?
    }

    nonisolated(unsafe) private static var held: [UInt32: Held] = [:]
    nonisolated(unsafe) private static var nextID: UInt32 = 1
    nonisolated(unsafe) private static var isInstalled = false
    nonisolated(unsafe) private static var pausedMode: UnsafeMutableRawPointer?
    nonisolated(unsafe) private static var isPaused = false

    static func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Registration? {
        installHandler()
        let id = nextID
        nextID += 1
        let reference = isPaused ? nil : add(shortcut, id: id)
        guard isPaused || reference != nil else { return nil }
        held[id] = Held(shortcut: shortcut, action: action, reference: reference)
        return Registration(id: id)
    }

    static func unregister(_ registration: Registration) {
        held[registration.id]?.reference.map { _ = UnregisterEventHotKey($0) }
        held[registration.id] = nil
    }

    static func pause(_ pauses: Bool) {
        guard pauses != isPaused else { return }
        isPaused = pauses
        if pauses {
            pausedMode = PushSymbolicHotKeyMode(OptionBits(kHIHotKeyModeAllDisabled))
            for id in held.keys {
                held[id]?.reference.map { _ = UnregisterEventHotKey($0) }
                held[id]?.reference = nil
            }
        } else {
            pausedMode.map { PopSymbolicHotKeyMode($0) }
            pausedMode = nil
            for (id, key) in held {
                held[id]?.reference = add(key.shortcut, id: id)
            }
        }
    }

    private static func add(_ shortcut: Shortcut, id: UInt32) -> EventHotKeyRef? {
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F505348), id: id)
        guard RegisterEventHotKey(shortcut.code, carbonModifiers(of: shortcut), hotKeyID, GetApplicationEventTarget(), 0, &reference) == noErr else { return nil }
        return reference
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
            HotKey.held[id.id]?.action()
            return noErr
        }, 1, &spec, nil, nil)
    }
}
