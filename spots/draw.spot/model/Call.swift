import Foundation

/// One block that Openspot writes to a staying spot: a call with its number, its arguments and the lines of its
/// message, or a stop of an earlier call.
enum Call: Equatable {
    case ask(id: Int, arguments: [String], input: [String: String])
    case stop(Int)

    /// Reads the lines of one block, or nil when they hold no call and no stop.
    init?(lines: [String]) {
        var id: Int?
        var arguments: [String] = []
        var input: [String: String] = [:]
        for line in lines {
            guard let cut = line.firstIndex(of: "=") else { continue }
            let value = String(line[line.index(after: cut)...])
            switch line[..<cut] {
            case "stop":
                guard let number = Int(value) else { return nil }
                self = .stop(number)
                return
            case "call": id = Int(value)
            case "arg": arguments.append(Call.text(value))
            default:
                let key = String(line[..<cut])
                if input[key] == nil { input[key] = Call.text(value) }
            }
        }
        guard let id else { return nil }
        self = .ask(id: id, arguments: arguments, input: input)
    }

    /// The real text of a written value: `\n` is a new line and `\\` is a backslash.
    static func text(_ written: String) -> String {
        var text = ""
        var escaped = false
        for sign in written {
            if escaped {
                text += sign == "n" ? "\n" : sign == "\\" ? "\\" : "\\\(sign)"
                escaped = false
            } else if sign == "\\" {
                escaped = true
            } else {
                text.append(sign)
            }
        }
        return escaped ? text + "\\" : text
    }

    /// A text as a value of one line.
    static func written(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n")
    }
}
