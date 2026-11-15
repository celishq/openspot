import Carbon
import Foundation
import OpenspotCore

@MainActor
enum SpotKeyLayouts {
    private static let keyCodes: ClosedRange<UInt16> = 0...50
    private static var observers: [NSObjectProtocol] = []
    private(set) static var latin: KeyLayout?

    static func start() {
        KeyLayout.enabled = read()
        latin = readLatin()
        guard observers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        let enabled = Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String)
        let selected = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        observers = [
            center.addObserver(forName: enabled, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    KeyLayout.enabled = read()
                    latin = readLatin()
                }
            },
            center.addObserver(forName: selected, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { latin = readLatin() }
            }
        ]
    }

    static func readLatin() -> KeyLayout? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
        return layout(source)
    }

    static func readCommandCode(of character: Character) -> UInt16? {
        let sources = [TISCopyCurrentKeyboardLayoutInputSource(), TISCopyCurrentASCIICapableKeyboardLayoutInputSource()].compactMap { $0?.takeRetainedValue() }
        return sources.lazy.compactMap { layout($0, modifiers: UInt32(cmdKey >> 8) & 0xFF)?.code(of: character) }.first
    }

    private static func read() -> [KeyLayout] {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return [] }
        return list.compactMap { layout($0) }
    }

    private static func layout(_ source: TISInputSource, modifiers: UInt32 = 0) -> KeyLayout? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        let keys: [UInt16: Character] = data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return [:] }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            return Dictionary(uniqueKeysWithValues: keyCodes.compactMap { code in character(code, in: layout, modifiers: modifiers).map { (code, $0) } })
        }
        return keys.isEmpty ? nil : KeyLayout(keys: keys)
    }

    private static func character(_ code: UInt16, in layout: UnsafePointer<UCKeyboardLayout>, modifiers: UInt32) -> Character? {
        var deadKeys: UInt32 = 0
        var length = 0
        var units = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), modifiers, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, units.count, &length, &units)
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: units, count: length)
        guard text.count == 1, let character = text.first, !character.isWhitespace, !character.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else { return nil }
        return character
    }
}
