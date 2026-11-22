import Foundation

extension BlockKind {
    static let commonKeys: Set<String> = [
        "title", "detail", "icon", "min", "max", "color", "value", "display",
        "placeholder", "readonly", "required", "type", "close", "confirm", "scope", "form",
        "shortcut", "tone", "unit", "recording", "grow", "parent", "class"
    ]
    private static let optionKeys: Set<String> = ["option", "title", "icon"]

    public static func faults(in block: TextBlock, kinds: [BlockKind] = BlockKind.all) -> [String] {
        BlockKind.of(block, in: kinds).map { faults(in: block, kind: $0) } ?? []
    }

    static func faults(in block: TextBlock, kind: BlockKind) -> [String] {
        let name = block.fields.first?.value ?? ""
        let known = commonKeys.union(kind.keys)
        var faults = kind.isOpen ? [] : block.fields.dropFirst().map(\.key).filter { !known.contains($0) }.map { "the part \(name) has an unknown key: \($0)" }
        for option in block.children {
            let id = option.value("option") ?? ""
            faults += option.fields.map(\.key).filter { !optionKeys.contains($0) }.map { "the option \(id) of \(name) has an unknown key: \($0)" }
        }
        faults += block.values("color").filter { !isColor($0) }.map { "the part \(name) needs a color as #rrggbb: \($0)" }
        if let tone = block.value("tone"), MetricValue.Tone(rawValue: tone) == nil {
            faults.append("the part \(name) has an unknown tone: \(tone)")
        }
        return faults + kind.faults(block)
    }

    @Sendable static func keyFaults(in block: TextBlock) -> [String] {
        guard let key = block.value("shortcut"), ActionKey(text: key) == nil else { return [] }
        let name = block.fields.first?.value ?? ""
        guard block.fields.first?.key == button.word else { return ["the part \(name) has an unknown key combination: \(key)"] }
        return ["the button \(name) has shortcut=\(key), which a button cannot take. Use cmd or shift with a letter, a digit, return, backspace or a comma, or escape"]
    }

    public static func actionFaults(in block: TextBlock) -> [String] {
        let id = block.value("button") ?? ""
        var faults = (block.value("title") == nil ? ["the button \(id) needs a title"] : []) + keyFaults(in: block)
        switch block.value("scope") {
        case nil, CommandAction.Scope.item.rawValue, CommandAction.Scope.spot.rawValue: break
        case let scope?: faults.append("the button \(id) has an unknown scope: \(scope). Use item or spot")
        }
        return faults
    }

    static func isColor(_ text: String) -> Bool {
        text.count == 7 && text.first == "#" && text.dropFirst().allSatisfy(\.isHexDigit)
    }
}
