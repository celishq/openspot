import XCTest
@testable import OpenspotCore

final class ProtocolContractTests: XCTestCase {
    private let gapsFile = RepoDoc.repo.appendingPathComponent("scripts/protocol-gaps.txt")

    private func source(_ path: String) throws -> String {
        try String(contentsOf: RepoDoc.repo.appendingPathComponent("app/\(path)"), encoding: .utf8)
    }

    private func missing(_ name: String, code: Set<String>, named: Set<String>) -> [String] {
        code.subtracting(named).map { "\(name) \($0): the code takes it, and no page of docs/protocol names it" }
    }

    private func gaps() throws -> [String] {
        let pages = try RepoDoc.protocolPages()
        let appWords = RepoDoc.tableRows(in: try RepoDoc("spots/AGENTS.md").section("The app's own words"))
        let spans = pages.flatMap { RepoDoc.code($0.prose) } + appWords.flatMap { RepoDoc.code($0[0]) }
        let named = Set(spans.map { String($0.prefix { $0 != "=" }) })
        let tables = Set(spans.filter { $0.hasPrefix("[") }.map { String($0.dropFirst().prefix { $0 != "." && $0 != "]" }) })
        let calls = Set(spans.filter { $0.hasPrefix("<spot> ") }.map { String($0.split(separator: " ")[1]) })

        let places = Set(SpotSize.all.compactMap { Style.Variant(size: $0)?.rawValue } + [Style.Variant.bar.rawValue])
        let uses = Set(SpotUse.allCases.map(\.rawValue))
        let docUses = Set(RepoDoc.tableRows(in: try RepoDoc("TRUST.md").section("Uses")).flatMap { RepoDoc.code($0[0]) })

        let variable = #"OPENSPOT_[A-Z_]*[A-Z]"#
        let scripts = try ["spots", "examples"].flatMap { folder -> [String] in
            let files = FileManager.default.enumerator(at: RepoDoc.repo.appendingPathComponent(folder), includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
            return try files.filter { ["sh", "js", "swift", "py"].contains($0.pathExtension) }.map { try String(contentsOf: $0, encoding: .utf8) }
        }
        let read = Set(scripts.flatMap { RepoDoc.matches(variable, in: $0).map { $0[0] } })
        let core = FileManager.default.enumerator(at: RepoDoc.repo.appendingPathComponent("app/Core"), includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        let set = Set(try core.filter { $0.pathExtension == "swift" }.flatMap { RepoDoc.matches(variable, in: try String(contentsOf: $0, encoding: .utf8)).map { $0[0] } })
        let docVariables = Set(RepoDoc.matches(variable, in: pages.map(\.text).joined() + appWords.map { $0[0] }.joined(separator: "\n")).map { $0[0] })

        let helper = try source("Shell/openspot.sh")
        let functions = Set(RepoDoc.matches(#"(?m)^([a-z][a-z_]*)\(\)"#, in: helper).map { $0[1] })
        let docFunctions = Set(spans.map { String($0.prefix { $0 != " " }) })

        return missing("manifest key", code: Manifest.keys, named: named)
            + missing("manifest table", code: Manifest.tables, named: tables)
            + missing("root key", code: Set(RootKey.allCases.map(\.rawValue)), named: named)
            + missing("block kind", code: BlockKind.words, named: named)
            + missing("item key", code: Set(ItemKey.allCases.map(\.rawValue)), named: named)
            + missing("event", code: Set(SpotEvent.known), named: named)
            + missing("place", code: places, named: named)
            + missing("call", code: Set(FrameCheck.calls), named: calls)
            + missing("shell helper", code: functions, named: docFunctions)
            + uses.symmetricDifference(docUses).map { "use \($0): TRUST.md and the code disagree on it" }
            + read.union(docVariables.intersection(set)).symmetricDifference(docVariables).map { "variable \($0): docs/protocol and the code disagree on it" }
    }

    func testEachKeyKindAndCallThatTheCodeTakesIsOnAPageOfTheProtocol() throws {
        let found = Set(try gaps())
        let listed = Set(try String(contentsOf: gapsFile, encoding: .utf8).components(separatedBy: "\n").filter { !$0.isEmpty })

        for gap in found.subtracting(listed).sorted() {
            XCTFail("\(gap). Fix the code or the page of docs/protocol.")
        }
        for gap in listed.subtracting(found).sorted() {
            XCTFail("\(gap): this gap is gone, so remove its line from scripts/protocol-gaps.txt.")
        }
    }

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

    func testEachVerbOfTheTableIsOneThatTheDocsOrTheGuideOfItsNounNames() throws {
        let protocolText = try (["TRUST.md", "app/Help/commands.md"].map(RepoDoc.init) + RepoDoc.protocolPages()).map(\.text).joined()
        for noun in CommandNoun.all {
            let text = try protocolText + (noun.guide.map { try RepoDoc("app/Help/\($0).md").text } ?? "")
            for verb in noun.verbs where !verb.about.isEmpty {
                let phrase = ([noun.name] + verb.words).joined(separator: " ")
                let listed = text.contains("`openspot \(phrase)") || text.contains("`\(phrase)")
                    || text.contains("`openspot \(noun.name) <verb>`") && text.contains("`\(verb.words.joined(separator: " "))`")
                XCTAssertTrue(listed, "docs/protocol, TRUST.md, app/Help/commands.md and the guide of \(noun.name) do not name `openspot \(phrase)`")
            }
        }
    }

    func testEachStatusWordAndSourceIDThatCoreWritesIsOneTheDocsName() throws {
        let commands = try RepoDoc("app/Help/commands.md").text
        let screen = try RepoDoc("app/Help/screen.md").text
        for status in TranslatedText.Status.allCases.map(\.rawValue) + [CalcRateFailure.offline, .unavailable].map(\.rawValue) {
            XCTAssertTrue(commands.contains("`status=\(status)`"), "app/Help/commands.md does not name status=\(status)")
        }
        for state in ScreenRecording.State.allCases {
            XCTAssertTrue(screen.contains("`state=\(state.rawValue)`"), "the guide of screen does not name state=\(state.rawValue)")
        }
        for kind in ScreenDevice.Kind.allCases.map(\.rawValue) + [ScreenDevice.system] {
            XCTAssertTrue(screen.contains("`\(kind):<id>`") || screen.contains("`\(kind)`"), "the guide of screen does not name the source \(kind)")
        }
    }
}
