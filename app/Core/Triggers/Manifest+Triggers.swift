import Foundation

extension Manifest {
    public struct Triggers: Equatable, Sendable {
        static let table = "on"
        static let command = ScriptEntry.command.name
        static let search = ScriptEntry.search.name
        static let schedule = ScriptEntry.schedule.name
        static let every = ScriptEntry.every.name
        static let drop = ScriptEntry.drop.name
        static let pick = EventName.attachmentPick
        static let keys = [command, search, schedule, every, drop, pick]
        static let events = EventName.declarable
        private static let named = [ScriptEntry.show, .press, .drag]
        static let cache = "cache"
        private static let spaces = Set(EventName.declarable.compactMap { $0.split(separator: ".").first.map(String.init) } + ["clock", "timer", cache])
        private static let ages: [Character: TimeInterval] = ["s": 1, "m": 60, "h": 3_600, "d": 86_400]

        public let commands: [String]
        public let search: AnswerPattern?
        public let lists: Bool
        public let schedule: [CronLine]
        public let every: Int?
        public let drop: DropKinds
        public let pick: AttachmentPick?
        public let events: [String]
        public let filters: [String: AnswerPattern]
        public let bindings: [BoundEvent]
        public let fills: [String: TimeInterval]

        public static let panel = Triggers(events: [EventName.panelOpen])
        public static let sheet = Triggers(events: [EventName.sheetOpen])

        public init(
            events: [String] = [], every: Int? = nil, search: AnswerPattern? = nil, lists: Bool = false, drop: DropKinds = DropKinds(), pick: AttachmentPick? = nil, commands: [String] = [],
            schedule: [CronLine] = [], filters: [String: AnswerPattern] = [:], bindings: [BoundEvent] = [], fills: [String: TimeInterval] = [:]
        ) {
            self.commands = commands
            self.search = search
            self.lists = lists
            self.schedule = schedule
            self.every = every
            self.drop = drop
            self.pick = pick
            self.events = events
            self.filters = filters
            self.bindings = bindings
            self.fills = fills
        }

        init(section: String, table: ConfigDocument.Table) throws {
            let fault = { (key: String, reason: String) in SpotError.fault("\(Manifest.fileName): \(section) \(key) \(reason)") }
            var commands: [String] = []
            var search: AnswerPattern?
            var lists = false
            var schedule: [CronLine] = []
            var every: Int?
            var drop = DropKinds()
            var pick: AttachmentPick?
            var events: [String] = []
            var filters: [String: AnswerPattern] = [:]
            var bindings: [BoundEvent] = []
            var fills: [String: TimeInterval] = [:]
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
                    guard !kinds.contains(where: { [AttachmentValue.Kind.url.rawValue, AttachmentValue.Kind.text.rawValue].contains($0.lowercased()) }) else {
                        throw fault(name, "takes files. Take a link or text with an action that has a url or text input.")
                    }
                    drop = DropKinds(kinds)
                case Self.pick:
                    guard case .string(let text)? = value else { throw fault(name, "takes \"browsers\", or a regular expression of the bundle ID of the front app, such as \"attachment.pick\" = \"^com\\\\.apple\\\\.Safari$\".") }
                    guard let found = AttachmentPick(text) else { throw fault(name, "is not a regular expression: \(text).") }
                    pick = found
                case let event where Self.events.contains(event):
                    switch value {
                    case .boolean(let isOn)?:
                        if isOn { events.append(event) }
                    case .string(let text)?:
                        guard !EventName.valueless.contains(event) else { throw fault(name, "has no value to match, so it takes only true.") }
                        guard let pattern = AnswerPattern(text) else { throw fault(name, "is not a regular expression: \(text).") }
                        events.append(event)
                        filters[event] = pattern
                    default:
                        throw fault(name, "takes true, or a regular expression of its value.")
                    }
                case let fill where fill.hasPrefix(Self.cache + "."):
                    let cache = String(fill.dropFirst(Self.cache.count + 1))
                    guard SpotCache.isName(cache), case .string(let text)? = value, let age = Self.age(text) else {
                        throw fault(name, "takes the age after which a read runs it, such as \"cache.rates\" = \"1d\". Use s, m, h or d.")
                    }
                    fills[cache] = age
                case let event where EventName.isName(event) && !Self.spaces.contains(String(event.prefix { $0 != "." })):
                    guard value == .boolean(true) else { throw fault(name, "takes true.") }
                    bindings.append(BoundEvent(key: event))
                default:
                    let known = (Self.keys + Self.events).joined(separator: ", ")
                    throw SpotError.fault("\(Manifest.fileName): \(section) has an unknown event: \(name). Use \(known), or <binding>.<event>.")
                }
            }
            self.init(events: events, every: every, search: search, lists: lists, drop: drop, pick: pick, commands: commands, schedule: schedule, filters: filters, bindings: bindings, fills: fills)
        }

        static func age(orSeconds text: String) -> TimeInterval? {
            Int(text).map(TimeInterval.init) ?? age(text)
        }

        static func age(_ text: String) -> TimeInterval? {
            guard let unit = text.last.flatMap({ ages[$0] }), let count = Int(text.dropLast()), count > 0 else { return nil }
            return TimeInterval(count) * unit
        }

        var handlers: [ScriptEntry] {
            var handlers = Self.named + events.filter { !ShowEvent.options.contains($0) }.map(ScriptEntry.event)
            if !commands.isEmpty { handlers.append(.command) }
            if search != nil { handlers.append(.search) }
            if !schedule.isEmpty { handlers.append(.schedule) }
            if every != nil { handlers.append(.every) }
            if drop.isDeclared { handlers.append(.drop) }
            if pick != nil { handlers.append(.event(Self.pick)) }
            handlers += fills.keys.sorted().map { ScriptEntry.event(Self.cache + "." + $0) }
            return handlers
        }

        private static let opens = [EventName.panelOpen, EventName.sheetOpen, EventName.sheetText]

        public var shows: Bool {
            !events.isEmpty || every != nil || lists
        }

        public var showsOnPanel: Bool {
            events.contains(EventName.panelOpen)
        }

        public func opens(over front: String?) -> Bool {
            guard let filter = filters[EventName.panelOpen] else { return showsOnPanel }
            return front.map(filter.matches) ?? false
        }

        func picks(over front: String?, browsers: [Browser]) -> Bool {
            guard let pick, let front else { return false }
            return pick.matches(front, browsers: browsers)
        }

        public var opensSheet: Bool {
            events.contains(EventName.sheetOpen) || searchesSheet
        }

        public var pages: Bool {
            events.contains(EventName.sheetMore)
        }

        public var searchesSheet: Bool {
            events.contains(EventName.sheetText)
        }

        public var waitsForEvents: Bool {
            !events.isEmpty && every == nil && !lists && !events.contains(where: Self.opens.contains)
        }

        public func admits(_ name: String, value: String?) -> Bool {
            guard events.contains(name), !Self.opens.contains(name) else { return false }
            guard let filter = filters[name] else { return true }
            return filter.matches(value ?? "")
        }

        var answersOnly: Bool {
            search != nil && events.isEmpty && every == nil
        }

        func answering(_ order: String?) -> Triggers {
            let ordered = order == "last" ? search?.last() : order == "card" ? search?.card() : search
            return Triggers(events: events, every: every, search: ordered, lists: lists, drop: drop, pick: pick, commands: commands, schedule: schedule, filters: filters, bindings: bindings, fills: fills)
        }

        var showing: Triggers {
            Triggers(events: events, every: every, filters: filters)
        }

        func check(_ manifest: Manifest, name: String) throws {
            if let bound = bindings.first(where: { bound in !manifest.bindings.contains { $0.name == bound.binding } }) {
                throw SpotError.fault("\(name) has [on] \(bound.key), which names no binding \(bound.binding). Add it to [bindings], such as \(bound.binding) = { spot = \"<id>\" }")
            }
            let names = Set(handlers.map(\.name) + events)
            if let action = manifest.actions.first(where: { names.contains($0.id) }) {
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
