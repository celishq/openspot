import Foundation

/// Every part that a script can print, and the faults a printed part can have. It is the contract of a sheet.
public enum PartCatalog {
    private static let keys: Set<String> = [
        "title", "detail", "icon", "min", "max", "color", "value", "option",
        "placeholder", "readonly", "required", "type", "close", "confirm", "scope", "form", "align", "look",
        "shortcut", "tone", "tint"
    ]
    /// The kinds whose blocks can hold keys of the plugin's own, which a view reads.
    private static let open: Set<String> = ["view"]

    /// The catalog, for a person or a model to read. It holds the whole language, so a sheet can be written from it alone.
    public static var text: String {
        [language, parts, streams, rules, examples].joined(separator: "\n")
    }

    private static let language = """
    # Writing a sheet

    A plugin prints a sheet as plain text, and the app draws it with native controls. The app draws the header, with an \
    icon, a title and a close button, so do not add these. The content is \(Int(SheetPlacement.width))pt wide, and at most \
    \(Int(SheetPlacement.maxHeight))pt tall.

    The text has blocks, split by one blank line. The first block is the head, and it holds the drawing. Each other block is \
    one component, and its first line is `<kind>=<id>`, such as `switch=wifi`. This first line is not a setting: its key \
    says what the component is, and its value names it. The other keys can come in any order. Each key and value is on its \
    own line, with no colon and no spaces around `=`.

    ## Layout

    Draw the sheet with one `grid=` line for each row. Each word is the id of a component, and the component fills the \
    rectangle of cells that its id covers. Every line has the same number of words, and the words of a line set the \
    columns, so a wider component takes more words. Four columns are usual.

    - `.` is an empty cell.
    - `grid=- - - -` is a divider. An id in that row, such as `grid=- - - swap`, is a component that crosses the divider and \
    centres on it.
    - A smaller area inside or across a larger one floats on top, with its own blurred background. This is how you make a \
    floating button. Text moves clear of it.

    A `repeat=a` block flows the rows of the script through the area `a`, and the area scrolls. Its own `grid=` lines are \
    a drawing in which each word is the place of one row, and the drawing repeats down: `grid=a` is a list, \
    `grid=a b c d e f g` is seven square buttons to a line, and `grid=a a b c` with `grid=a a d e` is one large place and \
    four small ones. A row is a block with `row=<id>`, `title` and a picture, and a row is picked by \
    `open <value>`. A square button shows its `icon`, and `row` is the word that a search \
    finds. The app draws the search field over the sheet. A sheet can repeat one area.

    A row draws its `icon`, its `title` and `detail`, its `tone` and its `shortcut`. `tone=on` puts a dot on a row's \
    picture, and `hides=<action>` leaves out an action that the row does not offer. A row that needs more offers it as an \
    action.

    Every row has one height: \(Int(SheetPlacement.rowHeight))pt. The gap between cells is \(Int(SheetPlacement.gap))pt. To \
    make something taller, draw more rows. Rows that hold a field, a list, a graph or a picture share the free height, and \
    the sheet then takes its full height. A column of four is about 60pt wide. You cannot set a size, a colour or a gap of \
    your own.

    A sheet with no drawing is one column of its components, and `section=<id>` starts a new group with a divider. A button \
    that no drawing places is an action: it shows in the ⌘K menu, and its `shortcut` works directly.

    """

    private static let parts = """
    ## Components

    | Kind and keys | Shows | Calls the script with |
    |---|---|---|
    | `text`, with `title`, `detail`, `icon` | A line: the title on the left, the detail on the right. | |
    | `text` with `value=0.84`, or with `max=100` and a `value=30` line for each bar | A small mark before the detail: a bar \
    from `value`, or bars from the values up to `max`. `tone=good`, `warn` or `bad` colours it. | |
    | `number`, with `value=42%`, optional `title` | A big number in a tile, with its title under it. It needs 2 columns of 4, and 2 rows with a title. | |
    | `switch`, with `value=true` or `value=false` | A switch at the end of the line. | `<id> true` or `false` |
    | `slider`, with `value=70`, optional `min`, `max`, `title`, `icon` | A slider, from 0 to 100 unless `min` and `max` say. Give each slider a `title` or an `icon`. | `<id> <number>` |
    | `choice`, with `color=#ff0000` for each colour, `value=#ff0000` | A row of swatches. One `color=` with a `title` is one small swatch at the end of the line. | `<id> <color>` |
    | `choice`, with `option=id:Title` for each choice, `value=id` | A menu. Drawn over two lines or more, a list to choose from, which scrolls. | `<id> <option id>` |
    | `field`, with `value=...`, optional `readonly=true`, `placeholder` | A text area, which scrolls. Write a line break as `\\n`. | `<id> <text>` |
    | `hotkey`, with `value=ctrl+space` and `title` | A key at the end of the line. A click records the next key that the person presses, and Esc cancels. | `<id> <key>`, such as `<id> cmd+k` |
    | `button`, with `title` | A button that fills its cell. | `<id>` |
    | `button`, with `icon=arrow.up` or another SF Symbol name | A round button, which shrinks to fit its area, up to 44pt. | `<id>` |
    | `graph`, with `value=3` for each bar | A bar chart in a tile. | |
    | `picture`, with `icon=/path/to/file` | A picture from a file. | |
    | `gauge`, with `value=0.4`, `title`, `detail` | A title line over a bar. It needs 2 rows. | |

    These keys change a component:

    | Key | Does |
    |---|---|
    | `icon=wifi` | A picture: an SF Symbol name, a path of a picture file such as `cup.png`, any other path for its Finder icon, or text such as 😀. |
    | `shortcut=cmd+return` | Adds a keyboard key to a button. The hint under the sheet shows it. Use cmd, shift and one letter, digit, return or backspace, or `escape` alone, which then presses the button, or runs the action, in place of closing the sheet. |
    | `close=true` | Closes the panel after a press. |
    | `align=left`, `right` or `center` | Places a component that is smaller than its cell. |
    | `look=tile`, `chip`, `strong` or `bare` | The box of a text, a number or a button. `tile` is a filled row. `chip` is a small capsule button. `strong` is the one main button, white. `bare` shows a button or a number with no fill. |
    | `look=tick` | Draws a switch as a round tick before its words, for a thing to do, such as a reminder. |
    | `tone=good`, `warn` or `bad` on a text | Colours its detail, or its title when it has no detail, such as a `Late` in red. |
    | `color=#1BADF8` | Draws a thin bar of that colour at the leading edge of a text or a number, such as the colour of a calendar. |

    """

    private static let streams = """
    ## Long work and running scripts

    A call can keep printing. A line `---` ends a frame, and the app draws it at once. A frame with a layout replaces the \
    sheet, and a frame with only components changes those components, so print each one whole again.

    A value over 64 KB is left out of the arguments, and stdin still holds it. In a shell script, `. "$OPENSPOT_SH"` gives \
    `value <id>`, which prints the real text of one value from stdin, and `esc <text>`, which writes text as a value. Loading \
    it reads all of stdin once. A script writes a file to a temp name, then moves it, so a file is never half written.

    A `read` has 10 seconds until its first frame or its end, and it stops when nothing wants it, such as when its sheet \
    closes. Any other name has no time limit, and it keeps running with the sheet and the panel closed. A new value for a component \
    stops the older call of that component. A second press of a running part, action or card stops its call: each process in its \
    group gets the terminate signal, and after 2 seconds Openspot kills what still runs. A press within 1 second of the start of \
    the call does nothing, so a double press does not stop it. Quitting Openspot stops each call. \
    After 1 second, a call that does work shows on its part, its action, its spot and the Openspot item in the menu bar. Its \
    last frame reports progress: `value` from 0 to 1 draws a ring, no `value` draws a spinner, and `title` and `detail` show on \
    the spot only while the call runs. To outlive the app, start the work with `nohup` and then exit. A stopped call changes nothing. Closing the panel \
    closes a sheet of parts, and one with a field drops its values.

    A script with `# stay=true` in its header is one process that talks both ways, such as a local server: it runs while something \
    wants it, and from the start of the app to its quit with `# stay=always`. Each call reaches it on stdin as one block and a blank line: \
    `call=<n>`, `reason=<word>` on a read, one `arg` for each argument of a normal call, and the values of the sheet. In the shell \
    helper, `while next; do case "$(arg 1)" in …` reads them, with `$call`, `$reason`, `$stop` and `value <id>`. It prints \
    frames at any time, and ends each call with `end=<n>` in a head: the frame that ends a read is its answer. A second press \
    sends the block `stop=<n>`. It must end, with each process it started, when its input ends.

    """

    private static let rules = """
    ## Rules

    - Every id in a drawing needs one component, and each component that is not a button needs its id in the drawing.
    - A component cannot be called `read`, `open` or `drop`.
    - Do not use a key that this page does not name.
    - Use at most one `look=strong`.
    - Keep titles short: about 7 letters fit in one column of four, with a control in the same cell.
    - A row of 8 swatches needs the full width.
    - Do not put plain lines beside a text area in the same rows, because those rows stretch. Draw a `choice` over two lines or more for a list.
    - Run `openspot check --sheet` on a sheet to see its faults, and `openspot render <file.png>` to see its picture.

    """

    private static var examples: String {
        "## Examples\n\n" + SheetExamples.all.map { "### \($0.name)\n\n```text\n\($0.text)```\n" }.joined(separator: "\n")
    }

    /// What is wrong with a block of a part, in words for a person or an agent.
    public static func faults(in block: TextBlock) -> [String] {
        let name = block.fields.first?.value ?? ""
        let isOpen = open.contains(block.fields.first?.key ?? "")
        var faults = isOpen ? [] : block.fields.dropFirst().map(\.key).filter { !keys.contains($0) }.map { "the part \(name) has an unknown key: \($0)" }
        faults += block.values("option").filter { !$0.contains(":") }.map { "the part \(name) needs an option as id:title: \($0)" }
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
