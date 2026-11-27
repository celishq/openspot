enum CommandKind {
    static let live: Set<String> = [
        "batch", "app status", "update check", "update install", "spot open", "spot review", "setting change",
        "power lid-closed", "power readings", "toast", "toast --remove", "select", "route push", "route back", "route close",
        "timer add", "timer remove", "attachment add", "browser tab", "browser tabs", "selection read", "front app", "access list", "access ask", "access grant", "app restart", "app settings", "cache get", "cache age", "cache set", "session open", "session back", "session forward"
    ]
    static let pure: Set<String> = ["date read", "emoji list", "symbols list"]
    static let help: Set<String> = ["--help", "-h"]

    static func needsApp(_ arguments: [String]) -> Bool {
        !arguments.contains(where: help.contains) && holds(arguments, in: live)
    }

    static func isPure(_ arguments: [String]) -> Bool {
        holds(arguments, in: pure)
    }

    private static func holds(_ arguments: [String], in names: Set<String>) -> Bool {
        guard let noun = arguments.first else { return false }
        return names.contains(noun) || (arguments.count > 1 && names.contains(noun + " " + arguments[1]))
    }
}
