import Foundation

/// One call of Openspot: its number, its arguments and the lines of its message.
struct Call {
    let id: String
    let arguments: [String]
    let input: [String]

    /// The first value of a key in its message, such as `setting.look` of `setting.look=gold`.
    func value(_ key: String) -> String? {
        input.first { $0.hasPrefix("\(key)=") }.map { Link.plain(String($0.dropFirst(key.count + 1))) }
    }
}

/// The two ways of a staying spot (protocol: Without the helper): the calls that Openspot writes on stdin, one block each,
/// and the frames that the spot prints back, each in one write.
enum Link {
    /// Reads stdin on a thread of its own, and hands each call and each stop to the main queue, then the end of stdin.
    static func listen(call: @escaping (Call) -> Void, stop: @escaping (String) -> Void, end: @escaping () -> Void) {
        Thread {
            var id: String?
            var stopped: String?
            var arguments: [String] = []
            var input: [String] = []
            while let line = readLine() {
                if line.isEmpty {
                    if let id {
                        let next = Call(id: id, arguments: arguments, input: input)
                        DispatchQueue.main.async { call(next) }
                    } else if let stopped {
                        DispatchQueue.main.async { stop(stopped) }
                    }
                    (id, stopped, arguments, input) = (nil, nil, [], [])
                } else if line.hasPrefix("call=") {
                    id = String(line.dropFirst(5))
                } else if line.hasPrefix("stop=") {
                    stopped = String(line.dropFirst(5))
                } else if line.hasPrefix("arg=") {
                    arguments.append(plain(String(line.dropFirst(4))))
                } else if id != nil {
                    input.append(line)
                }
            }
            DispatchQueue.main.async(execute: end)
        }.start()
    }

    /// Starts the output of a call.
    static func start(_ id: String) {
        write("call=\(id)\n---\n")
    }

    /// Prints a frame.
    static func frame(_ text: String) {
        write(text + "\n---\n")
    }

    /// Ends a call.
    static func end(_ id: String) {
        write("end=\(id)\n---\n")
    }

    /// Writes text as a value: a backslash as `\\` and a new line as `\n`.
    static func value(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n")
    }

    /// The real text of a value: `\n` as a new line and `\\` as a backslash.
    static func plain(_ text: String) -> String {
        var result = ""
        var escaped = false
        for character in text {
            if escaped {
                result += character == "n" ? "\n" : character == "\\" ? "\\" : "\\\(character)"
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    private static func write(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }
}
