enum CommandKind {
    static let live: Set<String> = [
        "batch", "app status", "update check", "update install", "spot open", "spot show", "spot review", "setting change",
        "event emit", "theme edit"
    ]
    static let pure: Set<String> = ["emoji", "symbols"]

    static func needsApp(_ arguments: [String]) -> Bool {
        holds(arguments, in: live)
    }

    static func isPure(_ arguments: [String]) -> Bool {
        holds(arguments, in: pure)
    }

    private static func holds(_ arguments: [String], in names: Set<String>) -> Bool {
        guard let noun = arguments.first else { return false }
        return names.contains(noun) || (arguments.count > 1 && names.contains(noun + " " + arguments[1]))
    }
}
