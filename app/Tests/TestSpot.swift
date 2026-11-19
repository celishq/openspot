import Foundation

struct TestSpot {
    static let toast = "'\(Bundle(for: FakeHost.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot").path)' toast"
    static let event = #"in=$(cat); ev=$(printf '%s\n' "$in" | sed -n 's/^event=//p'); val=$(printf '%s\n' "$in" | sed -n 's/^event\.value=//p')"#

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
