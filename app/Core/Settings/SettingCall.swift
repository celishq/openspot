import Foundation

public enum SettingCall: NounCall {
    case get(spot: String, key: String)
    case set(spot: String, key: String, value: String?)
    case list(PrintForm)
    case change(spot: String, key: String)
    case menuBar(spot: String, isShown: Bool)
    case key(spot: String, act: GlobalKey.Act, key: String?)
    case appKey(name: String, key: String)
    case login(Bool)
    case link(Bool)
    case careful(Bool)
    case slow(Bool)

    static let noun = CommandNoun("setting", group: .app, verbs: [
        CommandVerb("get", "[--spot id] <key>", "Prints the value the person chose for the spot, or nothing. A secret prints as •••, except to a run of its own spot.") { words in
            pair(words, sets: false) { spot, key, _ in Self.get(spot: spot, key: key) }
        },
        CommandVerb(
            "set", "[--spot id] <key> [value]",
            "Keeps a value for the spot, or removes it with no value. The person's choices of a spot: menubar (true or false), open, float and key.<command> (a key such as ctrl+option+k, or shake; none takes it away). Of the spot openspot: login, link, careful, slow (true or false), panel-key and fix-key."
        ) { words in
            pair(words, sets: true) { spot, key, value in reserved(spot, key, value, isInShow: words.isInShow) ?? Self.set(spot: spot, key: key, value: value) }
        },
        CommandVerb("list", "[--json]", "Prints a field=<key> block with spot and value for each value that a spot keeps. --json prints them as JSON.", rule: CallRule(use: .spots, used: "read the settings of each spot")) { words in
            words.form.map(Self.list)
        },
        CommandVerb("change", "[--spot id] <key>", "Runs the action of the setting in the panel, which can ask with a form.", rule: CallRule(inShow: .changes("opens a form"), flags: .needsApp)) { words in
            pair(words, sets: false) { spot, key, _ in Self.change(spot: spot, key: key) }
        }
    ], loose: { verb, rest, caller in
        guard rest.first == CallWords.spotWord, rest.count > 1 else { return nil }
        let call: SettingCall = verb.words == ["get"] ? .get(spot: rest[1], key: "") : .set(spot: rest[1], key: "", value: nil)
        return call.rule(verb.rule, spot: caller)
    })

    private static let careful = "cannot change Careful mode. Only you can, in Settings or with `openspot setting set --spot openspot careful true` in Terminal."

    private static func pair(_ words: CallWords, sets: Bool, _ call: (String, String, String?) -> any NounCall) -> (any NounCall)? {
        var rest = words.rest
        var spot = words.spot
        if rest.first == CallWords.spotWord {
            guard rest.count > 1 else { return nil }
            spot = rest[1]
            rest.removeFirst(2)
        }
        guard let key = rest.first, !key.isEmpty, !key.hasPrefix("-"), rest.count <= (sets ? 2 : 1) else { return nil }
        guard let spot else { return CallFault.refused("`openspot setting` needs a spot. Run it from a spot, or name one with `--spot <id>`.") }
        return call(spot, key, rest.dropFirst().first)
    }

    private static func reserved(_ spot: String, _ key: String, _ value: String?, isInShow: Bool) -> (any NounCall)? {
        let flag = value.flatMap { ["true": true, "false": false][$0] }
        let isApp = spot == ReservedSetting.appSpot && ReservedSetting.appKeys.contains(key)
        let name = "setting set \(isApp ? "--spot \(spot) " : "")\(key)"
        func on(_ act: String, _ call: (Bool) -> SettingCall) -> any NounCall {
            guard let flag else { return CallFault.refused("`\(key)` takes `true` or `false`, such as `openspot setting set --spot \(spot) \(key) true`.") }
            return changing(call(flag), act)
        }
        func changing(_ call: SettingCall, _ act: String) -> any NounCall {
            guard isInShow, let refusal = CallRule(inShow: .changes(act)).refusal(of: name) else { return call }
            return CallFault.refused(refusal)
        }
        if isApp {
            switch key {
            case "panel-key", "fix-key":
                guard let value else { return CallFault.refused("`\(key)` needs a key, such as `openspot setting set --spot openspot \(key) ctrl+space`.") }
                return changing(.appKey(name: key, key: value), "sets a key of your Mac")
            case "login": return on("changes your Mac", Self.login)
            case "link": return on("changes your Mac", Self.link)
            case "careful": return on("changes how spots run", Self.careful)
            case "slow": return on("changes how fast the panel moves", Self.slow)
            default: return nil
            }
        }
        switch key {
        case "menubar": return on("changes the menu bar") { .menuBar(spot: spot, isShown: $0) }
        case let key where GlobalKey.Act(setting: key) != nil:
            return changing(.key(spot: spot, act: GlobalKey.Act(setting: key) ?? .float, key: value), "sets a key of your Mac")
        default: return nil
        }
    }

    func rule(_ rule: CallRule, spot caller: String?) -> CallRule {
        func other(_ spot: String) -> Bool {
            caller.map { !SpotID(spot).isSameFolder(as: SpotID($0)) } ?? true
        }
        return switch self {
        case .get(let spot, _) where other(spot): CallRule(use: .spots, used: "read a setting of another spot")
        case .set(let spot, _, _) where other(spot), .change(let spot, _) where other(spot): CallRule(use: .spots, used: "changed a setting of another spot", inShow: rule.inShow)
        case .menuBar: CallRule(use: .app, used: "changed the menu bar")
        case .key, .appKey: CallRule(use: .app, used: "changed a key")
        case .login: CallRule(use: .app, used: "changed whether Openspot opens at login")
        case .link: CallRule(use: .app, used: "changed the openspot command in Terminal")
        case .careful: CallRule(use: .app, used: "changed Careful mode", onlyPerson: Self.careful)
        case .slow: CallRule(use: .app, used: "changed slow motion")
        default: rule
        }
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        let settings = SettingCalls(places: context.places, caller: context.spot, app: context.app, secrets: context.secrets, channel: context.channel?.id)
        let keys = KeyCalls(places: context.places, app: context.app)
        let apps = AppCalls(mac: context.mac, places: context.places, app: context.app)
        return switch self {
        case .get(let spot, let key): settings.get(key, of: spot)
        case .set(let spot, let key, let value): settings.set(key, of: spot, to: value)
        case .list(let form): settings.list(form)
        case .change(let spot, let key): settings.change(key, of: spot)
        case .menuBar(let spot, let isShown): MenuBarCalls(places: context.places, app: context.app).show(spot, isShown)
        case .key(let spot, let act, let key): keys.set(act, of: spot, to: key)
        case .appKey(let name, let key): keys.set(app: name, to: key)
        case .login(let isOn): apps.login(isOn)
        case .link(let isOn): apps.link(isOn)
        case .careful(let isOn): apps.careful(isOn)
        case .slow(let isOn): apps.slow(isOn)
        }
    }
}
