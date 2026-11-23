@testable import OpenspotCore

extension SpotWords {
    static func set(_ part: String, to value: String) -> SpotWords {
        SpotWords(arguments: [part, value])
    }

    static func drop(paths: [String]) -> SpotWords {
        SpotWords(arguments: [Handler.drop.name] + paths)
    }

    static func drag(runs: [String]) -> SpotWords {
        SpotWords(arguments: [Handler.drag.name] + runs)
    }
}
