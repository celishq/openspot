/// The two kinds of `openspot` call (protocol: The openspot command). A call of files reads or writes only files, or asks the Mac, and gives the same
/// answer with the app or without it, so it runs in a process of its own when the app is closed. A live call needs the
/// state of the running app, so it always goes to the app, which starts first when it is closed. A quit is about the app
/// that runs, so with none it runs alone and says so, and the stats then come from the files of each day.
enum CommandKind {
    /// The nouns, and the nouns with their verbs, of the live calls.
    private static let live: Set<String> = [
        "batch", "app status", "update check", "update install", "spot open", "spot show", "spot review", "setting change",
        "event emit"
    ]

    /// Whether a call with these arguments needs the running app.
    static func needsApp(_ arguments: [String]) -> Bool {
        guard let noun = arguments.first else { return false }
        return live.contains(noun) || (arguments.count > 1 && live.contains(noun + " " + arguments[1]))
    }
}
