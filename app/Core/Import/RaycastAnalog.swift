import Foundation

enum RaycastAnalog {
    static let spots: [String: [String]] = [
        "translate": ["translate", "google-translate", "deepl", "deepl-translate", "easydict"],
        "color-picker": ["color-picker", "pick-color", "colors"],
        "now-playing": ["spotify-player", "spotify", "spotify-controls", "music", "apple-music", "music-controls", "now-playing"],
        "caffeinate": ["caffeinate", "amphetamine", "coffee", "keep-awake"],
        "battery": ["battery", "battery-health", "coconut-battery"],
        "cpu": ["system-monitor", "stats", "kill-process", "process-killer"],
        "disk": ["disk-usage", "disk-space"],
        "emoji": ["emoji", "emoji-search", "emojis"],
        "windows": ["window-management", "rectangle", "window-walker", "window-sizer"],
        "calculator": ["calculator", "numi", "soulver"],
        "snippets": ["snippets", "snippet-manager"],
        "links": ["quicklinks", "bookmarks"],
        "shortcuts": ["shortcuts", "apple-shortcuts", "shortcuts-search"],
        "devices": ["bluetooth", "bluetooth-connector", "airpods", "airpods-battery"],
        "pulls": ["github", "github-pull-requests"],
        "repos": ["github-repository-search", "repos"],
        "agenda": ["google-calendar", "calendar", "my-schedule", "apple-calendar", "fantastical"],
        "clock": ["world-clock", "time-zones", "timezone-buddy", "clock"],
        "shot": ["screenshot", "screenshots", "cleanshot"],
        "record": ["screen-recorder", "record"],
        "dictate": ["dictation", "whisper-dictation", "speech-to-text"],
        "year": ["year-progress", "progress"],
        "files": ["file-search", "recent-files", "finder"],
        "draw": ["draw", "excalidraw"],
        "confetti": ["confetti", "raycast-confetti"]
    ]

    static let byExtension: [String: String] = Dictionary(spots.flatMap { spot, names in names.map { ($0, spot) } }) { first, _ in first }

    static func spot(for name: String) -> String? {
        byExtension[name]
    }
}
