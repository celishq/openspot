import XCTest
@testable import OpenspotCore

extension ConfigFile {
    func turn(_ id: String, on isOn: Bool) throws {
        try change { $0.arrangement.set(isEnabled: isOn, of: id) }
    }

    func showInMenuBar(_ id: String, _ isShown: Bool) throws {
        try change { $0.arrangement.set(isInMenuBar: isShown, of: id) }
    }

    func write(_ arrangement: SpotChoices) throws {
        try change { $0.arrangement = arrangement }
    }

    func write(keys: [GlobalKey]) throws {
        try change { $0.keys = keys }
    }

    func assign(_ trigger: Trigger?, to spot: String, act: GlobalKey.Act) throws {
        try change { $0.assign(trigger, to: spot, act: act) }
    }

    func set(setting key: String, of spot: String, to value: String?) throws {
        try change { $0.set(setting: key, of: spot, to: value) }
    }

    func set(_ key: String, to text: String) throws {
        let shortcut = try XCTUnwrap(Shortcut(text: text))
        try change { $0.set(shortcut, for: key) }
    }
}
