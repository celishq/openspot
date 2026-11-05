import Foundation

/// Every part that a script can print, and the faults a printed part can have. It is the contract of a sheet.
public enum PartCatalog {
    private static let keys: Set<String> = [
        "part", "section", "title", "detail", "symbol", "on", "level", "min", "max", "color", "value", "option", "text",
        "lines", "placeholder", "readonly", "press", "key", "close"
    ]
    private static let controls = ["on", "level", "color", "option", "text"]

    /// The catalog as blocks, for a person or an agent to read.
    public static let text = """
    part=section
    keys=section, title, detail, and any control or press
    shows=A divider and a bold line. Parts below it belong to it.

    part=line
    keys=part, title, detail, symbol
    shows=A label with a value on the right.

    part=switch
    keys=on
    calls=set <part> true|false
    shows=A switch at the end of the line.

    part=slider
    keys=level, min, max, symbol
    calls=set <part> <number>
    shows=A slider that fills the line.

    part=swatches
    keys=color for each swatch as #rrggbb, value
    calls=set <part> <color>
    shows=A row of colours to choose from.

    part=menu
    keys=option for each choice as id:title, value
    calls=set <part> <id>
    shows=A menu.

    part=text
    keys=text, lines, placeholder, readonly
    calls=set <part> <text>
    shows=A text area. With readonly=true it only shows the text, and the person can select it.

    part=button
    keys=press, key, close
    calls=press <part>
    shows=press=true makes the whole line a button. press=<symbol> adds a round button at its end.

    """

    /// What is wrong with a block of a part, in words for a person or an agent.
    public static func faults(in block: TextBlock) -> [String] {
        let name = block.value("part") ?? block.value("section") ?? ""
        var faults = block.fields.map(\.key).filter { !keys.contains($0) }.map { "the part \(name) has an unknown key: \($0)" }
        if controls.filter({ control in block.fields.contains { $0.key == control } }).count > 1 {
            faults.append("the part \(name) has more than one control")
        }
        faults += block.values("option").filter { !$0.contains(":") }.map { "the part \(name) needs an option as id:title: \($0)" }
        faults += block.values("color").filter { !isColor($0) }.map { "the part \(name) needs a color as #rrggbb: \($0)" }
        if let key = block.value("key"), ActionKey(text: key) == nil {
            faults.append("the part \(name) has an unknown key combination: \(key)")
        }
        return faults
    }

    private static func isColor(_ text: String) -> Bool {
        text.count == 7 && text.first == "#" && text.dropFirst().allSatisfy(\.isHexDigit)
    }
}
