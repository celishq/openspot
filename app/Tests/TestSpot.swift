import Foundation

struct TestSpot {
    static let toast = "'\(Bundle(for: FakeHost.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot").path)' toast"
    static let command = "[actions.go]\ntitle = 'Go'"
    static let event = #"in=$(cat); ev=$(printf '%s\n' "$in" | sed -n 's/^input\.event=//p'); [ "$1" = show ] || ev=$1; val=$(printf '%s\n' "$in" | sed -n 's/^input\.value=//p')"#

    let toml: String
    let body: String

    init(toml: String = "", body: String = "") {
        self.toml = toml
        self.body = body
    }

    var text: String {
        "#!/bin/sh\n\(body)\n"
    }

    func write(to url: URL) throws {
        try text.writeScript(to: url, toml: toml)
    }
}
