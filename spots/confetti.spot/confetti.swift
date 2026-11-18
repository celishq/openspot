#!/usr/bin/env swift

// Openspot builds this file with the Swift files of `confetti/`, and keeps one process while a call plays: the call
// ends when the last piece leaves the screens, so no process of Confetti runs at rest. The key that plays it is the key
// of Play in its Settings, and its look is the setting `look`, which holds the title or the id of a look.
import AppKit

/// The looks that ship in `looks`, and the person's own in the `looks` folder of the spot's data, by id.
struct Shelf {
    let builtIn = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("looks")
    let mine = URL(fileURLWithPath: ProcessInfo.processInfo.environment["OPENSPOT_DATA"] ?? "").appendingPathComponent("looks")

    /// The id of each look, the person's first when two share an id.
    var ids: [String] {
        var seen: [String] = []
        for folder in [builtIn, mine] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            for name in names.sorted() where name.hasSuffix(".look") {
                let id = String(name.dropLast(5))
                if !seen.contains(id) { seen.append(id) }
            }
        }
        return seen
    }

    func file(of id: String) -> String {
        let own = mine.appendingPathComponent("\(id).look").path
        return FileManager.default.fileExists(atPath: own) ? own : builtIn.appendingPathComponent("\(id).look").path
    }

    func title(of id: String) -> String {
        let title = Look.read(file(of: id)).0.title
        return title.isEmpty ? id : title
    }

    /// The look that a setting names by its id or its title, or Colorful.
    func chosen(_ setting: String?) -> String {
        guard let setting, !setting.isEmpty else { return "colorful" }
        return ids.first { $0 == setting } ?? ids.first { title(of: $0) == setting } ?? "colorful"
    }
}

let shelf = Shelf()
var plays: [String: Play] = [:]

/// Plays the look until its last piece leaves, then ends the call. A look that cannot play ends it with a toast.
func play(_ id: String, call: String) {
    let (look, faults) = Look.read(shelf.file(of: id))
    if let fault = faults.first {
        Link.frame("toast=\(Link.value("\(shelf.title(of: id)) cannot play. \(fault)"))")
        return Link.end(call)
    }
    plays[call] = Play(look) {
        plays[call] = nil
        Link.end(call)
    }
}

/// Answers the Look row of Settings: with no value, a form with a choice of each look; with one, keeps it and plays it.
func look(_ call: Call) {
    let picked = call.arguments.dropFirst().first ?? call.value("input.look") ?? ""
    let current = shelf.chosen(call.value("setting.look"))
    guard shelf.ids.contains(picked) else {
        var form = "title=Look\n\nchoice=look\ntitle=Look\nvalue=\(current)\n"
        for id in shelf.ids { form += "\noption=\(id)\ntitle=\(Link.value(shelf.title(of: id)))\n" }
        Link.frame(form)
        return Link.end(call.id)
    }
    let keep = Process()
    keep.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    keep.arguments = ["openspot", "setting", "set", "look", shelf.title(of: picked)]
    keep.standardInput = FileHandle.nullDevice
    keep.standardOutput = FileHandle.nullDevice
    keep.terminationHandler = { _ in
        DispatchQueue.main.async {
            plays.values.forEach { $0.stop() }
            play(picked, call: call.id)
        }
    }
    do { try keep.run() } catch { Link.end(call.id) }
}

Link.listen { call in
    Link.start(call.id)
    switch call.arguments.first {
    case "play", "open": play(shelf.chosen(call.value("setting.look")), call: call.id)
    case "look": look(call)
    default: Link.end(call.id)
    }
} stop: { id in
    plays[id]?.stop()
} end: {
    exit(0)
}
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
