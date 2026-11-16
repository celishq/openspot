import Foundation

struct KeyText: Equatable {
    private static let names: [(name: String, label: String)] = [("return", "⏎"), ("backspace", "⌫"), ("escape", "Esc")]
    private static let markOrder: [Shortcut.Modifiers] = [.control, .option, .shift, .command]

    let modifiers: Shortcut.Modifiers
    let name: String

    init(modifiers: Shortcut.Modifiers, name: String) {
        self.modifiers = modifiers
        self.name = name
    }

    init?(text: String) {
        var words = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let name = words.popLast(), !name.isEmpty else { return nil }
        var modifiers: Shortcut.Modifiers = []
        for word in words {
            guard let modifier = Shortcut.Modifiers(word: word) else { return nil }
            modifiers.insert(modifier)
        }
        self.init(modifiers: modifiers, name: name)
    }

    init?(label: String) {
        var rest = Substring(label)
        var modifiers: Shortcut.Modifiers = []
        while let modifier = Self.markOrder.first(where: { $0.mark.map(rest.hasPrefix) == true }) {
            modifiers.insert(modifier)
            rest = rest.dropFirst()
        }
        guard !rest.isEmpty else { return nil }
        let name = Self.names.first { $0.label == rest || (rest == "↩" && $0.name == "return") }?.name ?? rest.lowercased()
        self.init(modifiers: modifiers, name: name)
    }

    var text: String {
        (Shortcut.Modifiers.all.filter(modifiers.contains).compactMap(\.word) + [name]).joined(separator: "+")
    }

    var marks: String {
        Self.markOrder.filter(modifiers.contains).compactMap(\.mark).joined()
    }

    var keyLabel: String {
        Self.names.first { $0.name == name }?.label ?? (name.count == 1 ? name.uppercased() : name.capitalized)
    }

    var label: String {
        marks + keyLabel
    }
}
