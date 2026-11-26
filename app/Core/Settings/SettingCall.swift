import Foundation

public enum SettingCall: NounCall {
    case get(spot: String, key: String)
    case set(spot: String, key: String, value: String?)
    case remove(spot: String, key: String)
    case list(spot: String?, form: PrintForm)
    case change(spot: String, key: String)
    case menuBar(spot: String, isShown: Bool)
    case window(spot: String, isWindow: Bool)
    case key(spot: String, act: GlobalKey.Act, key: String?)
    case appKey(name: String, key: String?)
    case login(Bool)
    case link(Bool)
    case slow(Bool)
    case theme(String)

    static let noun = CommandNoun("setting", group: .app, verbs: [
        CommandVerb("get", "[--spot id] <key>", "Prints the value the person chose for the spot, or nothing. A secret prints as •••, except to a run of its own spot.") { words in
            pair(words, sets: false) { spot, key, _ in Self.get(spot: spot, key: key) }
        },
        CommandVerb(
            "set", "[--spot id] <key> [value]",
            "Keeps a value for the spot, or removes it with no value. The person's choices of a spot: menubar, window (true or false), attachment (false hides the chip of a source), open, float and key.<command> (a key such as ctrl+option+k, or shake; none takes it away). Of the spot openspot: login, link, slow (true or false), panel-key, fix-key and theme (the name of a theme)."
        ) { words in
            pair(words, sets: true) { spot, key, value in reserved(spot, key, value, isInShow: words.isInShow) ?? Self.set(spot: spot, key: key, value: value) }
        },
        CommandVerb(
            "remove", "[--spot id] <key>",
            "Removes the value the person chose for the spot, a secret too. Only you can, in Settings or in Terminal; a spot cannot.",
            rule: CallRule(use: .spots, used: "removed a setting", inShow: .changes("removes a setting"), onlyPerson: "cannot remove a setting. Only you can, in Settings or with `openspot setting remove` in Terminal.")
        ) { words in
            pair(words, sets: false) { spot, key, _ in removedKey(spot, key) ?? Self.remove(spot: spot, key: key) }
        },
        CommandVerb(
            "list", "[--spot id] [--json]",
            "Prints each row of Settings, of the app and of each spot, or of one spot (openspot for the app): item, spot, key (what setting set takes), title, value (a secret prints set), kind (key, field, toggle, choice, secret or text), section (general, developer, keys, look, account or spot), icon and detail. --json prints them as JSON.",
            rule: CallRule(use: .spots, used: "read the settings of each spot")
        ) { words in
            words.form.map { Self.list(spot: words.fit?.value(CallWords.spotWord), form: $0) }
        },
        CommandVerb("change", "[--spot id] <key>", "Runs the action of the setting in the panel, which can ask with a form.", rule: CallRule(inShow: .changes("opens a form"), flags: .needsApp)) { words in
            pair(words, sets: false) { spot, key, _ in Self.change(spot: spot, key: key) }
        }
    ], loose: { verb, rest, caller in
        guard rest.first == CallWords.spotWord, rest.count > 1 else { return nil }
        let call: SettingCall = verb.words == ["get"] ? .get(spot: rest[1], key: "") : .set(spot: rest[1], key: "", value: nil)
        return call.rule(verb.rule, spot: caller)
    })

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

    static func setting(_ spot: String, _ key: String, to value: String?) -> any NounCall {
        reserved(spot, key, value, isInShow: false) ?? Self.set(spot: spot, key: key, value: value)
    }

    static func removing(_ spot: String, _ key: String) -> SettingCall {
        removedKey(spot, key) ?? .remove(spot: spot, key: key)
    }

    private static func removedKey(_ spot: String, _ key: String) -> SettingCall? {
        if spot == ReservedSetting.appSpot, AppSetting(rawValue: key)?.isKey == true { return .appKey(name: key, key: nil) }
        return GlobalKey.Act(setting: key).map { .key(spot: spot, act: $0, key: nil) }
    }

    private static func reserved(_ spot: String, _ key: String, _ value: String?, isInShow: Bool) -> (any NounCall)? {
        let flag = value.flatMap { ["true": true, "false": false][$0] }
        let app = spot == ReservedSetting.appSpot ? AppSetting(rawValue: key) : nil
        let name = "setting set \(app == nil ? "" : "--spot \(spot) ")\(key)"
        func on(_ act: String, _ call: (Bool) -> SettingCall) -> any NounCall {
            guard let flag else { return CallFault.refused("`\(key)` takes `true` or `false`, such as `openspot setting set --spot \(spot) \(key) true`.") }
            return changing(call(flag), act)
        }
        func changing(_ call: SettingCall, _ act: String) -> any NounCall {
            guard isInShow, let refusal = CallRule(inShow: .changes(act)).refusal(of: name) else { return call }
            return CallFault.refused(refusal)
        }
        switch app {
        case .theme:
            guard let value else { return CallFault.refused("`theme` needs the name of a theme, such as `openspot setting set --spot openspot theme Openspot`.") }
            return changing(.theme(value), "changes the theme")
        case .panelKey, .fixKey:
            guard let value else { return CallFault.refused("`\(key)` needs a key, such as `openspot setting set --spot openspot \(key) ctrl+space`.") }
            return changing(.appKey(name: key, key: value), "sets a key of your Mac")
        case .login: return on("changes your Mac", Self.login)
        case .link: return on("changes your Mac", Self.link)
        case .slow: return on("changes how fast the panel moves", Self.slow)
        case nil: break
        }
        switch key {
        case SpotRows.menuBarKey: return on("changes the menu bar") { .menuBar(spot: spot, isShown: $0) }
        case SpotRows.windowKey: return on("changes how a spot opens") { .window(spot: spot, isWindow: $0) }
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
        case .list(let spot?, _) where !other(spot): CallRule()
        case .set(let spot, _, _) where other(spot), .change(let spot, _) where other(spot): CallRule(use: .spots, used: "changed a setting of another spot", inShow: rule.inShow)
        case .menuBar: CallRule(use: .app, used: "changed the menu bar")
        case .window: CallRule(use: .app, used: "changed how a spot opens")
        case .key, .appKey: CallRule(use: .app, used: "changed a key")
        case .login: CallRule(use: .app, used: "changed whether Openspot opens at login")
        case .link: CallRule(use: .app, used: "changed the openspot command in Terminal")
        case .slow: CallRule(use: .app, used: "changed slow motion")
        case .theme: CallRule(use: .app, used: "switched the theme")
        default: rule
        }
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        let settings = SettingCalls(places: context.places, caller: context.spot, app: context.app, secrets: context.secrets, channel: context.channel?.id, mac: context.mac)
        let keys = KeyCalls(places: context.places, app: context.app)
        let apps = AppCalls(mac: context.mac, places: context.places, app: context.app)
        return switch self {
        case .get(let spot, let key): settings.get(key, of: spot)
        case .set(let spot, let key, let value): settings.set(key, of: spot, to: value)
        case .remove(let spot, let key): settings.remove(key, of: spot)
        case .list(let spot, let form): settings.list(of: spot, form)
        case .change(let spot, let key): settings.change(key, of: spot)
        case .menuBar(let spot, let isShown): MenuBarCalls(places: context.places, app: context.app).show(spot, isShown)
        case .window(let spot, let isWindow): settings.window(of: spot, isWindow)
        case .key(let spot, let act, let key): keys.set(act, of: spot, to: key)
        case .appKey(let name, let key): keys.set(app: name, to: key)
        case .login(let isOn): apps.login(isOn)
        case .link(let isOn): apps.link(isOn)
        case .slow(let isOn): apps.slow(isOn)
        case .theme(let name): ThemeCall.use(name).work(in: context)
        }
    }
}
