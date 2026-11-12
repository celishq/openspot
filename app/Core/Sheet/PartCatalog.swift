import Foundation

/// Every key that a part can hold, as the kinds table of the guide names them, and the faults a printed part can have.
public enum PartCatalog {
    static let keys: Set<String> = [
        "title", "detail", "icon", "min", "max", "color", "value", "display",
        "placeholder", "readonly", "required", "type", "close", "confirm", "scope", "form", "align", "look",
        "shortcut", "tone"
    ]
    /// The kinds whose blocks can hold keys of the plugin's own, which a view reads.
    private static let open: Set<String> = ["view"]
    /// The keys of an `option` block after a choice.
    private static let optionKeys: Set<String> = ["option", "title", "icon"]

    /// What is wrong with a block of a part, in words for a person or an agent.
    public static func faults(in block: TextBlock) -> [String] {
        let name = block.fields.first?.value ?? ""
        let isOpen = open.contains(block.fields.first?.key ?? "")
        var faults = isOpen ? [] : block.fields.dropFirst().map(\.key).filter { !keys.contains($0) && $0 != "option" }.map { "the part \(name) has an unknown key: \($0)" }
        if !block.values("option").isEmpty {
            faults.append("the part \(name) has option lines, which Openspot no longer reads. Print each option as a block after its choice, such as option=en with title=English")
        }
        for option in block.children {
            let id = option.value("option") ?? ""
            faults += option.fields.map(\.key).filter { !optionKeys.contains($0) }.map { "the option \(id) of \(name) has an unknown key: \($0)" }
        }
        faults += block.values("color").filter { !isColor($0) }.map { "the part \(name) needs a color as #rrggbb: \($0)" }
        if let look = block.value("look"), SpotPart.Look(rawValue: look) == nil {
            faults.append("the part \(name) has an unknown look: \(look)")
        }
        if let align = block.value("align"), SpotPart.Align(rawValue: align) == nil {
            faults.append("the part \(name) has an unknown align: \(align)")
        }
        if let tone = block.value("tone"), MetricValue.Tone(rawValue: tone) == nil {
            faults.append("the part \(name) has an unknown tone: \(tone)")
        }
        if block.fields.first?.key == "slider", let level = block.number("value") {
            let low = block.number("min") ?? 0, high = block.number("max") ?? 100
            if level < low || level > high {
                faults.append("the part \(name) has a level of \(Int(level)), outside \(Int(low)) to \(Int(high))")
            }
        }
        if block.fields.first?.key == "hotkey" {
            if let shortcut = block.value("value"), Shortcut(text: shortcut) == nil {
                faults.append("the part \(name) needs a shortcut that holds cmd, ctrl or option: \(shortcut)")
            }
        } else if let key = block.value("shortcut"), ActionKey(text: key) == nil {
            faults.append("the part \(name) has an unknown key combination: \(key)")
        }
        return faults
    }

    private static func isColor(_ text: String) -> Bool {
        text.count == 7 && text.first == "#" && text.dropFirst().allSatisfy(\.isHexDigit)
    }
}
