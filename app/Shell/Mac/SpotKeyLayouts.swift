import Carbon
import Foundation
import OpenspotCore

/// The keyboard layouts that the person turned on, read from the Mac into `KeyLayout.enabled` as the app starts and each
/// time the person turns one on or off. An input method with no key layout, such as Pinyin, gives none.
@MainActor
enum SpotKeyLayouts {
    private static let keyCodes: ClosedRange<UInt16> = 0...50
    private static var observer: NSObjectProtocol?

    static func start() {
        KeyLayout.enabled = read()
        guard observer == nil else { return }
        let name = Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String)
        observer = DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { KeyLayout.enabled = read() }
        }
    }

    /// The Latin layout that the Mac keeps for ⌘ shortcuts, such as ABC, read when a key needs it (A17).
    static var latin: KeyLayout? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
        return layout(source)
    }

    private static func read() -> [KeyLayout] {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return [] }
        return list.compactMap(layout)
    }

    private static func layout(_ source: TISInputSource) -> KeyLayout? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        let keys: [UInt16: Character] = data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return [:] }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            return Dictionary(uniqueKeysWithValues: keyCodes.compactMap { code in character(code, in: layout).map { (code, $0) } })
        }
        return keys.isEmpty ? nil : KeyLayout(keys: keys)
    }

    /// The printable character that a key types with no modifier and no dead key.
    private static func character(_ code: UInt16, in layout: UnsafePointer<UCKeyboardLayout>) -> Character? {
        var deadKeys: UInt32 = 0
        var length = 0
        var units = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, units.count, &length, &units)
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: units, count: length)
        guard text.count == 1, let character = text.first, !character.isWhitespace, !character.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else { return nil }
        return character
    }
}
