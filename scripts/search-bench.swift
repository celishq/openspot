import Foundation

/// Times each keystroke of the search over copies of the real lists, built with the Core sources at -O by
/// `scripts/search-bench.sh`. The first argument is the folder of the lists, the second the folder of the keywords.
/// Each scene types its words a letter at a time, then deletes them a letter at a time, as a person does.

let data = URL(fileURLWithPath: CommandLine.arguments[1])
let keywordFolder = URL(fileURLWithPath: CommandLine.arguments[2])
let rounds = 30

func items(_ name: String) -> [SpotItem] {
    PluginOutput(text: (try? String(contentsOf: data.appendingPathComponent("\(name).txt"), encoding: .utf8)) ?? "").items
}

func glyphItems() -> [SpotItem] {
    let file = data.appendingPathComponent("emoji.txt")
    if !FileManager.default.fileExists(atPath: file.path) {
        let keywords = GlyphKeywords(folder: keywordFolder)
        let text = ((try? EmojiCatalog(keywords: keywords).rows(tone: .none)) ?? "") + ((try? SymbolCatalog(keywords: keywords).rows()) ?? "")
        try? text.write(to: file, atomically: true, encoding: .utf8)
    }
    return items("emoji")
}

/// The ANSI key codes of the letter keys, in the order of `us` and `ru`.
let codes: [UInt16] = [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 6, 7, 8, 9, 11, 45, 46, 43, 47, 50]
let us = Array("qwertyuiop[]asdfghjkl;'zxcvbnm,.`")
let ru = Array("йцукенгшщзхъфывапролджэячсмитьбюё")
KeyLayout.enabled = [
    KeyLayout(keys: Dictionary(uniqueKeysWithValues: zip(codes, us))),
    KeyLayout(keys: Dictionary(uniqueKeysWithValues: zip(codes, ru)))
]

/// The texts of one word as it is typed and then deleted, a letter at a time.
func keystrokes(_ words: [String]) -> [String] {
    words.flatMap { word in
        let typed = (1...word.count).map { String(word.prefix($0)) }
        return typed + typed.reversed().dropFirst() + [""]
    }
}

func now() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
}

/// Prints the spread of the time of one keystroke, in milliseconds.
func report(_ name: String, _ times: [UInt64]) {
    let sorted = times.sorted().map { Double($0) / 1_000_000 }
    let at = { (share: Double) in sorted[min(Int(Double(sorted.count) * share), sorted.count - 1)] }
    print(String(format: "%-16@ keys %5d  p50 %6.3f  p90 %6.3f  p99 %6.3f  max %6.3f ms", name as NSString, sorted.count, at(0.5), at(0.9), at(0.99), sorted.last ?? 0))
}

/// Runs `step` for each keystroke, once to warm up and then `rounds` times, and reports the time of each keystroke.
func scene(_ name: String, _ texts: [String], _ step: (String) -> Void) {
    texts.forEach(step)
    var times: [UInt64] = []
    times.reserveCapacity(texts.count * rounds)
    for _ in 0..<rounds {
        for text in texts {
            let start = now()
            step(text)
            times.append(now() - start)
        }
    }
    report(name, times)
}

let spots = items("spots")
let apps = items("apps")
let settings = items("settings")
let glyphs = glyphItems()
print("items: spots \(spots.count), apps \(apps.count), settings \(settings.count), emoji and symbols \(glyphs.count)")

let spotItems = spots.map { SpotItem(title: $0.title, subtitle: $0.subtitle, run: $0.run) }
let sources = [ItemList(items: apps), ItemList(items: settings)]
let foldedSpots = ItemList(items: spotItems)
let mainWords = keystrokes(["system settings", "appearance", "safari", "bluetooth", "terminal", "сафари"])

scene("main search", mainWords) { text in
    _ = SearchQuery(text: text).matching(in: [foldedSpots] + sources, unpickedLimit: 3)
}
scene("spot list fold", mainWords) { _ in
    _ = ItemList(items: spotItems)
}
var settingsList = ItemList(items: settings)
scene("settings sheet", keystrokes(["appearance", "bluetooth", "keyboard", "display", "дисплей"])) { text in
    settingsList.search(text)
}
var glyphList = ItemList(items: glyphs)
scene("emoji sheet", keystrokes(["smile", "heart", "cat", "thumbs up", "сердце"])) { text in
    glyphList.search(text)
}
