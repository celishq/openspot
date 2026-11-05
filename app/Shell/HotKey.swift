import AppKit
import Carbon.HIToolbox

/// System-wide keys, which need no permission from the person.
enum HotKey {
    struct Registration {
        fileprivate let id: UInt32
        fileprivate let reference: EventHotKeyRef
    }

    nonisolated(unsafe) private static var actions: [UInt32: () -> Void] = [:]
    nonisolated(unsafe) private static var nextID: UInt32 = 1
    nonisolated(unsafe) private static var isInstalled = false

    static func register(code: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Registration? {
        installHandler()
        let id = nextID
        nextID += 1
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F505348), id: id)
        guard RegisterEventHotKey(code, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &reference) == noErr,
              let reference else { return nil }
        actions[id] = action
        return Registration(id: id, reference: reference)
    }

    static func unregister(_ registration: Registration) {
        UnregisterEventHotKey(registration.reference)
        actions[registration.id] = nil
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
