enum CommandKind {
    private static let live: Set<String> = [
        "batch", "app status", "update check", "update install", "spot open", "spot show", "spot review", "setting change",
        "event emit"
    ]

    static func needsApp(_ arguments: [String]) -> Bool {
        guard let noun = arguments.first else { return false }
        return live.contains(noun) || (arguments.count > 1 && live.contains(noun + " " + arguments[1]))
    }
}
