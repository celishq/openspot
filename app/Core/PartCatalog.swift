import Foundation

/// Every part that a script can print, and the faults a printed part can have. It is the contract of a sheet.
public enum PartCatalog {
    private static let keys: Set<String> = [
        "part", "section", "title", "detail", "symbol", "on", "level", "min", "max", "color", "value", "option", "text",
        "lines", "placeholder", "readonly", "press", "key", "close", "cell", "fill", "align", "look", "block", "metric", "point",
        "image", "item"
    ]
    private static let controls = ["on", "level", "color", "option", "text", "metric", "point", "image", "item"]

    /// The catalog, for a person or a model to read. It holds the whole language, so a sheet can be written from it alone.
    public static var text: String {
        [language, layouts, parts, streams, rules, examples].joined(separator: "\n")
    }

    private static let language = """
    # Writing a sheet

    A plugin prints a sheet as plain text, and the app draws it with native controls. The app draws the header, with an \
    icon, a title and a close button, so do not add these. The content is \(Int(SheetPlacement.width))pt wide, and at most \
    \(Int(SheetPlacement.maxHeight))pt tall.

    The text has blocks, split by one blank line. The first block is the layout. Each other block is one part, and holds \
    `part=<id>`. The order of keys in a block does not matter. Each key and value is on its own line, with no colon and no \
    spaces around `=`.

    ## Layout

    Use a name when one fits, because a name gives the best result. Write `layout=<name>`, and each `cell=` uses a cell name. \
    A cell with no part stays empty.

    If no name fits, draw the sheet in letters, with one `grid=` line for each row. Every line has the same number of \
    columns, and four is usual.

    - A letter, or any one character, names an area. The area is the rectangle around all its cells.
    - `.` is an empty cell.
    - `grid=- - - -` is a divider. A letter in that row, such as `grid=- - - x`, is a part that crosses the divider and \
    centres on it.
    - `card=s i t o` makes these letters share one background. Their text loses its own box.
    - A smaller area inside or across a larger one floats on top, with its own blurred background. This is how you make a \
    floating button. Text moves clear of it.
    - `keys=7 8 9 +` adds a row of key buttons. Use it for any keypad, in place of a part for each key. A word that repeats \
    next to itself spans those cells. Pressing a key calls `press <word>`.

    Every row has one height: \(Int(SheetPlacement.rowHeight))pt, or \(Int(SheetPlacement.keyRowHeight))pt when the sheet \
    has keys. The gap between cells is always \(Int(SheetPlacement.gap))pt. To make something taller, draw more rows. \
    A column of four is about 60pt wide. You cannot set a size, a colour or a gap of your own.

    A sheet with no drawing is one column of lines. `section=<id>` in place of `part=<id>` starts a new group with a divider.

    """

    private static var layouts: String {
        let rows = SheetLayout.named.keys.sorted().map { name -> String in
            let named = SheetLayout.named[name]!
            let drawing = named.drawing.map { "`\($0)`" }.joined(separator: " / ")
            let cells = named.cells.sorted { $0.key < $1.key }.map { "`\($0.key)`=\($0.value)" }.joined(separator: " ")
            return "| `\(name)` | \(named.purpose) | \(drawing) | \(cells) |"
        }
        return """
        ## Named layouts

        | Name | For | Its drawing | Cell names |
        |---|---|---|---|
        \(rows.joined(separator: "\n"))

        """
    }

    private static let parts = """
    ## Parts

    What the block holds decides what it shows. A part holds one control.

    | Keys | Shows | Calls the script with |
    |---|---|---|
    | `title`, `detail`, `symbol` | A line: the title on the left, the detail on the right. | |
    | `on=true` or `on=false` | A switch at the end of the line. | `set <id> true` or `false` |
    | `level=70`, optional `min`, `max`, `title`, `symbol` | A slider, from 0 to 100 unless `min` and `max` say. Give each slider a `title` or a `symbol`. | `set <id> <number>` |
    | `color=#ff0000` for each colour, `value=#ff0000` | A row of swatches. One `color=` with a `title` is one small swatch at the end of the line. | `set <id> <color>` |
    | `option=id:Title` for each choice, `value=id` | A menu. | `set <id> <option id>` |
    | `item=id:Title` for each row, `value=id` | A list to choose from, which scrolls. Use it for any list of rows. | `set <id> <item id>` |
    | `text=...`, optional `readonly=true`, `placeholder` | A text area, which scrolls. Write a line break as `\\n`. | `set <id> <text>` |
    | `press=true`, with `title` | A button that fills its cell. | `press <id>` |
    | `press=arrow.up` or another SF Symbol name | A round button, which shrinks to fit its area, up to 44pt. | `press <id>` |
    | `metric=42%`, optional `title` | A big number in a tile. It needs 2 columns of 4, and 2 rows with a title. | |
    | `point=3` for each bar | A bar chart in a tile. | |
    | `image=/path/to/file` | A picture from a file. | |
    | `block=progress`, `level`, `title`, `detail` | A title line over a bar. It needs 2 rows. | |

    These keys change a part:

    | Key | Does |
    |---|---|
    | `cell=a` | Puts the part on a letter or a named cell. |
    | `key=cmd+return` | Adds a keyboard key to a press. The hint under the sheet shows it. Use cmd, shift and one letter, digit, return or backspace. |
    | `close=true` | Closes the panel after a press. |
    | `fill=true` | This part's rows share the free height, and the sheet takes its full height. |
    | `align=left`, `right` or `center` | Places a part that is smaller than its cell. |
    | `look=tile`, `chip`, `strong`, `bare` or `section` | `tile` is a filled row. `chip` is a small capsule button. `strong` is the one main button, white. `bare` shows a button or a metric with no fill. `section` makes a bold title. |

    """

    private static let streams = """
    ## Long work and running scripts

    A call can keep printing. A line `---` ends a frame, and the app draws it at once. A frame with a layout replaces the \
    sheet, and a frame with only parts changes those parts, so print `part`, `cell` and the keys again for each one. A new \
    `set` or `press` stops the running call, and so does closing the sheet.

    A script with `# live=true` in its header runs while its sheet is open, so a model or a connection stays loaded between \
    events. It gets one block on its standard input for each event, with a blank line after it: `event=read`, `event=set` \
    with `id` and `value`, or `event=press` with `id`. It keeps its own state, and answers with frames. It must end when its \
    input ends.

    """

    private static let rules = """
    ## Rules

    - Every letter in a drawing needs one part, and two parts cannot share a letter.
    - Do not use a key that this page does not name.
    - Use at most one `look=strong`.
    - Keep titles short: about 7 letters fit in one column of four, with a control in the same cell.
    - A row of 8 swatches needs the full width.
    - Do not stretch rows of plain lines with `fill=true` beside them. Use `item=` for a list.
    - Run `openspot check --sheet` on a sheet to see its faults, and `openspot render <file.png>` to see its picture.

    """

    private static var examples: String {
        "## Examples\n\n" + SheetExamples.all.map { "### \($0.name)\n\n```text\n\($0.text)```\n" }.joined(separator: "\n")
    }

    /// What is wrong with a block of a part, in words for a person or an agent.
    public static func faults(in block: TextBlock) -> [String] {
        let name = block.value("part") ?? block.value("section") ?? ""
        var faults = block.fields.map(\.key).filter { !keys.contains($0) }.map { "the part \(name) has an unknown key: \($0)" }
        if controls.filter({ control in block.fields.contains { $0.key == control } }).count > 1 {
            faults.append("the part \(name) has more than one control")
        }
        faults += block.values("option").filter { !$0.contains(":") }.map { "the part \(name) needs an option as id:title: \($0)" }
        faults += block.values("color").filter { !isColor($0) }.map { "the part \(name) needs a color as #rrggbb: \($0)" }
        if let look = block.value("look"), SpotPart.Look(rawValue: look) == nil || look == "key" {
            faults.append("the part \(name) has an unknown look: \(look)")
        }
        if let align = block.value("align"), SpotPart.Align(rawValue: align) == nil {
            faults.append("the part \(name) has an unknown align: \(align)")
        }
        if let kind = block.value("block"), kind != "progress" {
            faults.append("the part \(name) has an unknown block: \(kind)")
        }
        if let level = block.number("level") {
            let low = block.number("min") ?? 0, high = block.number("max") ?? 100
            if level < low || level > high {
                faults.append("the part \(name) has a level of \(Int(level)), outside \(Int(low)) to \(Int(high))")
            }
        }
        if let key = block.value("key"), ActionKey(text: key) == nil {
            faults.append("the part \(name) has an unknown key combination: \(key)")
        }
        return faults
    }

    private static func isColor(_ text: String) -> Bool {
        text.count == 7 && text.first == "#" && text.dropFirst().allSatisfy(\.isHexDigit)
    }
}
