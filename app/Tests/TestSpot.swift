import Foundation

struct TestSpot {
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
