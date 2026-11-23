enum CommandKind {
    static let live: Set<String> = [
        "batch", "app status", "update check", "update install", "spot open", "spot review", "setting change",
        "power lid-closed", "power readings", "toast", "select", "route push", "route back", "route close",
        "timer add", "timer remove", "context add"
    ]
    static let pure: Set<String> = ["emoji list", "symbols list"]
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
