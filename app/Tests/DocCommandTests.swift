import XCTest
@testable import OpenspotCore

final class DocCommandTests: XCTestCase {
    func testEachOpenspotCommandThatADocNamesIsOneTheCommandTakes() throws {
        let usage = CommandLineCall.usage.components(separatedBy: "\n").filter { $0.hasPrefix("openspot ") }.map { line in
            line.split(separator: " ").prefix { !$0.hasPrefix("<") && !$0.hasPrefix("[") && !$0.hasPrefix("-") }.map(String.init)
        }
        for doc in try ["GUIDE.md", "PROTOCOL.md", "USING.md"].map(RepoDoc.init) + RepoDoc.all().filter({ $0.path.hasPrefix("app/Help/") || $0.path.hasPrefix("docs/protocol/") }) {
            let named = RepoDoc.matches("`(openspot [^`]*)`", in: doc.prose).map { $0[1] }
                + doc.fences.filter { $0.language == "sh" }.flatMap { RepoDoc.matches(#"(?m)^(openspot [^"&|\n]*)"#, in: $0.text).map { $0[1] } }
            for command in named {
                let filled = command.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"<[^>]*>"#, with: "x", options: .regularExpression)
                    .replacingOccurrences(of: "...", with: "")
                let words = filled.split(separator: " ").map(String.init)
                let call = CommandLineCall(arguments: Array(words.dropFirst()))
                let parsed: Bool = if case .unknown(_)? = call?.value as? CallFault { false } else { call != nil }
                let literal = command.split(separator: " ").prefix { !$0.hasPrefix("<") && !$0.hasPrefix("[") && !$0.hasPrefix("-") }.map(String.init)
                let named = usage.contains { form in
                    form.count >= literal.count && zip(form, literal).allSatisfy { pair in pair.0.split(separator: "|").contains { $0 == pair.1 } }
                }
                XCTAssertTrue(parsed || named, "\(doc.path) names `\(command)`, which openspot does not take")
            }
        }
    }
}
