import AppKit
import Carbon.HIToolbox

enum HotKey {
    nonisolated(unsafe) static var onPress: (() -> Void)?
    nonisolated(unsafe) private static var reference: EventHotKeyRef?

    static func registerControlSpace(_ action: @escaping () -> Void) {
        onPress = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.onPress?()
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x4F505348), id: 1)
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey), id, GetApplicationEventTarget(), 0, &reference)
    }
}
