import Foundation

enum PanelCall: NounCall {
    case act(PanelAct, name: String)
    case type(String, pace: Duration, clear: Bool)
    case keys([String])
    case state(json: Bool)
    case wait([(key: String, value: String)], within: TimeInterval)

    private static let rule = CallRule(use: .app, used: "drove the panel", inShow: .changes("moves the panel"), flags: .needsApp)
    private static let read = CallRule(flags: .needsApp)
    private static let pace = 80
    private static let within: TimeInterval = 10
    private static let look: Duration = .milliseconds(16)

    static let noun = CommandNoun("panel", group: .app, verbs: [
        CommandVerb("open", "", "Opens the panel, as its key does.", rule: rule) { $0.none ? Self.act(.open, name: "panel open") : nil },
        CommandVerb("close", "", "Closes the panel.", rule: rule) { $0.none ? Self.act(.close, name: "panel close") : nil },
        CommandVerb("type", "<text> [--pace <ms>] [--clear]", "Types the text into the field one character at a time, --pace milliseconds apart (80 by default), after the text the field holds, or in place of it with --clear.", rule: rule) { words in
            guard let fit = words.fit, fit.rest.count == 1 else { return nil }
            guard let pace = fit.value("--pace").map({ Int($0) }) ?? Self.pace, pace >= 0 else { return nil }
            return Self.type(fit.rest[0], pace: .milliseconds(pace), clear: fit.has("--clear"))
        },
        CommandVerb("key", "<key>...", "Presses each key as the keyboard does, such as return, escape, tab, up, down, cmd+k or shift+cmd+[.", rule: rule) { words in
            words.none ? nil : Self.keys(words.rest)
        },
        CommandVerb("press", "<part>", "Presses a part of the open sheet by its id, such as a button.", rule: rule) { words in
            words.one.map { Self.act(.press($0), name: "panel press \($0)") }
        },
        CommandVerb("state", "[--json]", "Prints what the panel shows: open, text, sheet, route, selected, menu, chips and moving.", rule: read) { words in
            guard let fit = words.fit, fit.rest.isEmpty else { return nil }
            return Self.state(json: fit.has("--json"))
        },
        CommandVerb("wait", "<key>=<value>... [--within <age>]", "Waits until panel state shows each fact, for 10 s or the age of --within, and fails with the first fact it missed.", rule: read) { words in
            Self.wait(words.rest)
        }
    ])

    static func == (lhs: PanelCall, rhs: PanelCall) -> Bool {
        switch (lhs, rhs) {
        case (.act(let a, let x), .act(let b, let y)): a == b && x == y
        case (.type(let a, let x, let p), .type(let b, let y, let q)): a == b && x == y && p == q
        case (.keys(let a), .keys(let b)): a == b
        case (.state(let a), .state(let b)): a == b
        case (.wait(let a, let x), .wait(let b, let y)): a.map { "\($0.key)=\($0.value)" } == b.map { "\($0.key)=\($0.value)" } && x == y
        default: false
        }
    }

    private static func wait(_ words: [String]) -> PanelCall? {
        var rest = words
        var within = Self.within
        if rest.count >= 2, rest[rest.count - 2] == "--within" {
            guard let age = Manifest.Triggers.age(orSeconds: rest[rest.count - 1]), age > 0 else { return nil }
            within = age
            rest.removeLast(2)
        }
        let facts = rest.compactMap { word -> (key: String, value: String)? in
            guard let mark = word.firstIndex(of: "="), mark != word.startIndex else { return nil }
            return (String(word[..<mark]), String(word[word.index(after: mark)...]))
        }
        guard !facts.isEmpty, facts.count == rest.count else { return nil }
        return .wait(facts, within: within)
    }

    static func key(_ word: String) -> ActionKey? {
        let parts = word.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let name = parts.last, !name.isEmpty else { return nil }
        let modifiers = Set(parts.dropLast())
        guard modifiers.isSubset(of: ["cmd", "shift"]), modifiers.count == parts.count - 1 else { return nil }
        return ActionKey(name: name, isCommand: modifiers.contains("cmd"), isShift: modifiers.contains("shift"))
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard let app = context.app, let clock = context.runs?.clock else { return CommandAnswer.notRunning("panel") }
        return switch self {
        case .act(let act, let name):
            CommandAnswer.work {
                guard await app.take(act) else { throw SpotError.failed(1, Self.refusal(of: act, name: name)) }
                return ""
            }
        case .type(let text, let pace, let clear):
            CommandAnswer.work {
                var typed = clear ? "" : await app.panelState().values["text"] ?? ""
                if clear { _ = await app.take(.type("")) }
                for (index, character) in text.enumerated() {
                    if index > 0 { try await clock.sleep(pace, nil) }
                    typed.append(character)
                    _ = await app.take(.type(typed))
                }
                return ""
            }
        case .keys(let words):
            CommandAnswer.work {
                for word in words {
                    guard let key = Self.key(word) else {
                        throw SpotError.failed(1, "Openspot can't press \(word), because it is not a key. Name a key such as return, escape, tab, up, down or cmd+k.")
                    }
                    guard await app.take(.key(key)) else {
                        throw SpotError.failed(1, "Openspot can't press \(word), because nothing in the panel takes it now. Run `openspot panel state` to see what shows.")
                    }
                }
                return ""
            }
        case .state(let json):
            CommandAnswer.work {
                let state = await app.panelState()
                return json ? state.json : state.lines
            }
        case .wait(let facts, let within):
            CommandAnswer.work {
                if let unknown = facts.first(where: { !PanelState.keys.contains($0.key) }) {
                    throw SpotError.failed(1, "The panel has no fact \(unknown.key). Wait for \(PanelState.keys.joined(separator: ", ")).")
                }
                let end = clock.now().addingTimeInterval(within)
                while true {
                    guard let missing = await app.panelState().missing(facts) else { return "" }
                    guard clock.now() < end else {
                        throw SpotError.failed(1, "The panel never showed \(missing) within \(Int(within.rounded())) s. Run `openspot panel state` to see what it shows.")
                    }
                    try await clock.sleep(Self.look, nil)
                }
            }
        }
    }

    private static func refusal(of act: PanelAct, name: String) -> String {
        switch act {
        case .press(let id): "Openspot can't press \(id), because the sheet shows no part \(id). Run `openspot panel state` to see what shows."
        default: "Openspot can't run `openspot \(name)` now."
        }
    }
}
