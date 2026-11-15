import Foundation

struct TestSpot {
    let header: String
    let body: String

    init(header: String = "", body: String = "") {
        self.header = header
        self.body = body
    }

    var text: String {
        let lines = header.isEmpty ? [] : header.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? "#" : "# \($0)" }
        return "#!/bin/sh\n\(lines.joined(separator: "\n"))\n\(body)\n"
    }

    func write(to url: URL) throws {
        try text.writeScript(to: url)
    }
}
