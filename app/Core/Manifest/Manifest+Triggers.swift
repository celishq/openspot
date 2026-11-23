import Foundation

extension Manifest {
    public struct Triggers: Equatable, Sendable {
        static let table = "on"
        static let command = "command"
        static let search = "search"
        static let schedule = "schedule"
        static let every = "every"
        static let drop = "drop"
        static let keys = [command, search, schedule, every, drop]
        static let events = SpotEvent.known
        static let named: Set<String> = ["show", "press", "drag"]
        private static let spaces = Set(SpotEvent.known.compactMap { $0.split(separator: ".").first.map(String.init) } + ["clock", "timer"])

        public let commands: [String]
        public let search: AnswerPattern?
        public let lists: Bool
        public let schedule: [CronLine]
        public let every: Int?
        public let drop: [String]
        public let events: [String]
        public let filters: [String: AnswerPattern]
        public let bindings: [BoundEvent]

        init() {
            commands = []
            search = nil
            lists = false
            schedule = []
            every = nil
            drop = []
            events = []
            filters = [:]
            bindings = []
        }

        init(section: String, table: ConfigDocument.Table) throws {
            let fault = { (key: String, reason: String) in SpotError.fault("\(Manifest.fileName): \(section) \(key) \(reason)") }
            var commands: [String] = []
            var search: AnswerPattern?
            var lists = false
            var schedule: [CronLine] = []
            var every: Int?
            var drop: [String] = []
            var events: [String] = []
            var filters: [String: AnswerPattern] = [:]
            var bindings: [BoundEvent] = []
            for key in table.keys {
                let name = Manifest.path(key).joined(separator: ".")
                let value = table[key]
                switch name {
                case Self.command:
                    guard case .strings(let words)? = value else { throw fault(name, "takes a list of words, such as command = [\"snooze\"].") }
                    if let word = words.first(where: { !Self.isWord($0) }) {
                        throw fault(name, "has a word that cannot follow a /: \(word). Start it with a letter, and use letters, digits, - and _.")
                    }
                    commands = words
                case Self.search:
                    if case .boolean(let isOn)? = value {
                        lists = isOn
                        continue
                    }
                    guard case .string(let text)? = value else { throw fault(name, "takes true, or a regular expression, such as search = \"^[0-9]\".") }
                    guard let pattern = AnswerPattern(text) else { throw fault(name, "is not a regular expression: \(text).") }
                    search = pattern
                case Self.schedule:
                    guard case .strings(let lines)? = value else { throw fault(name, "takes a list of cron lines, such as schedule = [\"0 9 * * 1-5\"].") }
                    for line in lines {
                        guard let cron = CronLine(line) else {
                            throw fault(name, "has a line that is not cron: \(line). Write minute, hour, day, month and weekday, such as \"0 9 * * 1-5\".")
                        }
                        schedule.append(cron)
                    }
                case Self.every:
                    guard case .integer(let seconds)? = value, seconds > 0 else { throw fault(name, "takes a whole number of seconds, such as every = 60.") }
                    every = seconds
                case Self.drop:
                    guard case .strings(let kinds)? = value else { throw fault(name, "takes a list of file types, such as drop = [\"png\", \"folder\"].") }
                    drop = kinds
                case let event where Self.events.contains(event):
                    switch value {
                    case .boolean(let isOn)?:
                        if isOn { events.append(event) }
                    case .string(let text)?:
                        guard !SpotEvent.valueless.contains(event) else { throw fault(name, "has no value to match, so it takes only true.") }
                        guard let pattern = AnswerPattern(text) else { throw fault(name, "is not a regular expression: \(text).") }
                        events.append(event)
                        filters[event] = pattern
                    default:
                        throw fault(name, "takes true, or a regular expression of its value.")
                    }
                case let event where SpotEvent.isName(event) && !Self.spaces.contains(String(event.prefix { $0 != "." })):
                    guard value == .boolean(true) else { throw fault(name, "takes true.") }
                    bindings.append(BoundEvent(key: event))
                default:
                    let known = (Self.keys + Self.events).joined(separator: ", ")
                    throw SpotError.fault("\(Manifest.fileName): \(section) has an unknown event: \(name). Use \(known), or <binding>.<event>.")
                }
            }
            self.commands = commands
            self.search = search
            self.lists = lists
            self.schedule = schedule
            self.every = every
            self.drop = drop
            self.events = events
            self.filters = filters
            self.bindings = bindings
        }

        var handlers: Set<String> {
            var names = Self.named.union(events)
            if !commands.isEmpty { names.insert(Self.command) }
            if search != nil { names.insert(Self.search) }
            if !schedule.isEmpty { names.insert(Self.schedule) }
            if every != nil { names.insert(Self.every) }
            if !drop.isEmpty { names.insert(Self.drop) }
            return names
        }

        var showEvents: ShowEvents {
            var moments: [ShowEvents.Moment] = []
            for event in events {
                switch event {
                case SpotEvent.sheetOpen, SpotEvent.sheetText: if !moments.contains(.sheet) { moments.append(.sheet) }
                case SpotEvent.panelOpen: moments.append(.panel)
                default: moments.append(.event(event))
                }
            }
            if let every { moments.append(.every(TimeInterval(every))) }
            return ShowEvents(moments: moments, answers: search, searchesSheet: events.contains(SpotEvent.sheetText), filters: filters)
        }

        func check(_ manifest: Manifest, name: String) throws {
            if let bound = bindings.first(where: { bound in !manifest.bindings.contains { $0.name == bound.binding } }) {
                throw SpotError.fault("\(name) has [on] \(bound.key), which names no binding \(bound.binding). Add it to [bindings], such as \(bound.binding) = { spot = \"<id>\" }")
            }
            if let action = manifest.actions.first(where: { handlers.contains($0.id) }) {
                throw SpotError.fault("\(name) has \(action.section), which takes the name of a handler that its [on] calls. Give the action another ID")
            }
        }

        func unheard(by name: String, through spots: [Binding], declared: [String: [String]]) -> String? {
            for bound in bindings {
                guard let spot = spots.first(where: { $0.name == bound.binding })?.spot, let events = declared[spot], !events.contains(bound.event) else { continue }
                return "\(name) has [on] \(bound.key), but \(spot) declares no event \(bound.event). " + (events.isEmpty ? "It declares no [events]." : "Name one of its [events]: \(events.joined(separator: ", "))")
            }
            return nil
        }

        private static func isWord(_ word: String) -> Bool {
            guard word.first?.isLetter == true else { return false }
            return word.allSatisfy { $0.isLetter || $0.isNumber || "-_".contains($0) }
        }
    }
}
