import Foundation
import Observation

@MainActor
@Observable
public final class KeyRecording {
    public private(set) var held: Shortcut.Modifiers = []
    public private(set) var pressed: String?
    public private(set) var isKeyDown = false
    public internal(set) var status: String?
    @ObservationIgnored private var lastHeld: Shortcut.Modifiers = []
    @ObservationIgnored private(set) var pressedCode: UInt32?
    @ObservationIgnored private(set) var taken: [TakenKey] = []

    public init(status: String? = nil) {
        self.status = status
    }

    func start() {
        if status != nil { status = nil }
        clear()
    }

    func clear() {
        if !held.isEmpty { held = [] }
        lastHeld = []
        if pressed != nil { pressed = nil }
        pressedCode = nil
        if isKeyDown { isKeyDown = false }
    }

    func take(_ taken: [TakenKey]) {
        self.taken = taken
    }

    func hold(_ modifiers: Shortcut.Modifiers) -> UInt32? {
        guard modifiers != held else { return nil }
        held = modifiers
        if !modifiers.isEmpty { lastHeld = modifiers }
        if isKeyDown, let pressedCode { return pressedCode }
        if !modifiers.isEmpty, status != nil { status = nil }
        return nil
    }

    func release() {
        if isKeyDown { isKeyDown = false }
    }

    func press(_ code: UInt32) {
        pressedCode = code
    }

    func refuse(code: UInt32, modifiers: Shortcut.Modifiers) {
        pressed = Shortcut.keyLabel(of: code)
        isKeyDown = pressed != nil
        if let key = pressed, modifiers.contains(.shift), !modifiers.makesShortcut {
            let typed = key.count == 1 && key.first?.isLetter == true ? "types a capital \(key)" : "types"
            status = "`⇧\(key)` \(typed) in every app. Hold `⌃`, `⌥` or `⌘` with it."
            return
        }
        status = pressed == nil && modifiers.makesShortcut
            ? "Openspot cannot use that key. Try a letter, a digit, a sign or an arrow."
            : "Hold ⌃, ⌥ or ⌘ with a key."
    }

    func refuseAppKey(_ shortcut: Shortcut) {
        pressed = shortcut.keyLabel
        isKeyDown = true
        status = "\(Self.appWords(shortcut))."
    }

    func check(_ shortcut: Shortcut) {
        status = words(for: shortcut)
    }

    func appCameToFront(_ name: String) {
        guard !held.isEmpty else { return }
        status = "\(held.marks) and a key opened \(name). Change it there, or press another key."
        held = []
    }

    func inputSourceChanged() {
        let modifiers = held.isEmpty ? lastHeld : held
        guard !modifiers.isEmpty else { return }
        let key = taken.first { $0.shortcut.modifiers == modifiers && SystemKeys.switchesInput($0) }
        status = "`\(key?.shortcut.label ?? modifiers.marks)` switches the input source. Free it in Keyboard Shortcuts."
        held = []
    }

    func use(of shortcut: Shortcut) -> String? {
        taken.first { $0.shortcut == shortcut }?.use
    }

    func words(for shortcut: Shortcut) -> String {
        guard let use = use(of: shortcut) else { return "\(shortcut.label) is free." }
        return "\(shortcut.label) \(use)."
    }

    static func appWords(_ shortcut: Shortcut) -> String {
        "`\(shortcut.label)` belongs to apps. Hold `⌥` or `⌃` with a key"
    }
}
