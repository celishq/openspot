import Foundation

enum WrittenCalls {
    static func calls(in text: String) -> [[String]] {
        let shell = text.matches(of: /openspot[ \t]+([a-z]+)[ \t]+([a-z-]+)((?:[ \t]+[^\s;|&)]+)*)/).map { match in
            [String(match.1), String(match.2)] + match.3.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(unquoted)
        }
        let inline = text.matches(of: /openspot\.call\(\s*\[([^\]]*)\]/).map { match in
            match.1.split(separator: ",").map(unquoted)
        }
        return shell + inline
    }

    private static func unquoted(_ word: Substring) -> String {
        word.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'"))
    }
}
