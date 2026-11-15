import AppKit
import OpenspotCore

@MainActor
final class GlobalKeys {
    private let model: SpotsModel
    private let toggle: @MainActor () -> Void
    private let fault: @MainActor (String) -> Void
    private let fix: @MainActor (String, URL) -> Void
    private var entry: HotKey.Registration?
    private var wanted: [GlobalKey] = []
    private var held: [GlobalKey: HotKey.Registration] = [:]
    private var keyFaults: [String] = []
    private var configFaults: [String] = []
    private var shakeWatch: SpotShakeWatch?
    private var tapWatch: SpotTapWatch?

    init(model: SpotsModel, toggle: @escaping @MainActor () -> Void, fault: @escaping @MainActor (String) -> Void, fix: @escaping @MainActor (String, URL) -> Void) {
        self.model = model
        self.toggle = toggle
        self.fault = fault
        self.fix = fix
    }

    func apply(_ config: Config) {
        var faults = config.faults
        let key = config.panelKey ?? model.entryKey
        if entry == nil || key != model.entryKey {
            if let registration = register(key) {
                entry.map(HotKey.unregister)
                entry = registration
                model.entryKey = key
            } else {
                faults.append("Openspot cannot use `\(key.label)` to open, because another app uses it. Choose another key.")
            }
        }
        if faults != configFaults, !faults.isEmpty { fault(faults.joined(separator: " ")) }
        configFaults = faults
    }

    func setEntry(on isOn: Bool) {
        entry.map(HotKey.unregister)
        entry = isOn ? register(model.entryKey) : nil
        if isOn {
            holdWanted()
        } else {
            held.values.forEach(HotKey.unregister)
            held = [:]
        }
        watchShake()
    }

    func hold(_ keys: [GlobalKey]) {
        wanted = keys
        holdWanted()
    }

    private func holdWanted() {
        watchShake()
        watchTap()
        guard model.recording == nil else { return }
        for (key, registration) in held where !wanted.contains(key) {
            HotKey.unregister(registration)
            held[key] = nil
        }
        var faults: [String] = []
        for key in wanted where held[key] == nil {
            guard case .key(let shortcut) = key.trigger else { continue }
            let registration = HotKey.register(shortcut) { [weak self] in
                MainActor.assumeIsolated { self?.model.press(key) }
            }
            if let registration {
                held[key] = registration
            } else {
                faults.append("\(key.spot) cannot use `\(shortcut.label)`, because another app uses it. Choose another key.")
            }
        }
        if faults != keyFaults, !faults.isEmpty { fault(faults.joined(separator: " ")) }
        keyFaults = faults
    }

    private func register(_ key: Shortcut) -> HotKey.Registration? {
        HotKey.register(key) { [weak self] in
            MainActor.assumeIsolated { self?.toggle() }
        }
    }

    private func watchShake() {
        let isWanted = wanted.contains { $0.trigger == .shake } || model.recording != nil
        if isWanted, shakeWatch == nil {
            shakeWatch = SpotShakeWatch { [weak self] in self?.takeShake() }
        } else if !isWanted {
            shakeWatch?.stop()
            shakeWatch = nil
        }
    }

    private func watchTap() {
        let isWanted = wanted.contains { if case .tap = $0.trigger { true } else { false } }
        if isWanted, tapWatch == nil {
            tapWatch = SpotTapWatch { [weak self] modifier in self?.takeTap(modifier) }
            if !AXIsProcessTrusted() {
                fix("Openspot cannot hear a tap of one key. Allow Openspot in Accessibility.", URL(string: SpotClipboard.accessibility)!)
            }
        } else if !isWanted {
            tapWatch?.stop()
            tapWatch = nil
        }
    }

    private func takeTap(_ modifier: Shortcut.Modifiers) {
        guard model.recording == nil, let key = wanted.first(where: { $0.trigger == .tap(modifier) }) else { return }
        model.press(key)
    }

    private func takeShake() {
        if model.recording != nil {
            model.recordShake()
        } else if let key = wanted.first(where: { $0.trigger == .shake }) {
            model.press(key)
        }
    }
}
