import Foundation

public struct CallWords: Sendable {
    static let spotWord = "--spot"
    public static let spotVariable = "OPENSPOT_ID"
    public static let reasonVariable = ReadReason.variable

    public let rest: [String]
    public let spot: String?
    public let reason: String?

    var isRead: Bool {
        reason != nil
    }

    func options(_ allowed: Set<String>) -> Set<String>? {
        Set(rest).count == rest.count && Set(rest).isSubset(of: allowed) ? Set(rest) : nil
    }

    var form: PrintForm? {
        options([PrintForm.frameWord]).map { $0.isEmpty ? .json : .frame }
    }

    var one: String? {
        rest.count == 1 ? rest[0] : nil
    }

    var none: Bool {
        rest.isEmpty
    }
}

extension CallWords {
    static func listing(_ words: [String]) -> (days: Int, hidden: [String])? {
        var days = 1
        var hidden: [String] = []
        var index = 0
        while index < words.count {
            guard index + 1 < words.count else { return nil }
            let value = words[index + 1]
            switch words[index] {
            case "--days":
                guard let number = Int(value), number > 0 else { return nil }
                days = number
            case "--hide": hidden.append(value)
            default: return nil
            }
            index += 2
        }
        return (days, hidden)
    }

    static func adding(_ words: [String]) -> (words: String, isDry: Bool)? {
        let isDry = words.first == "--dry-run"
        let rest = isDry ? Array(words.dropFirst()) : words
        return rest.isEmpty ? nil : (rest.joined(separator: " "), isDry)
    }
}
