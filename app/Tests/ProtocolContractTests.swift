import XCTest
@testable import OpenspotCore

final class ProtocolContractTests: XCTestCase {
    private let gapsFile = RepoDoc.repo.appendingPathComponent("scripts/protocol-gaps.txt")

    private func source(_ path: String) throws -> String {
        try String(contentsOf: RepoDoc.repo.appendingPathComponent("app/\(path)"), encoding: .utf8)
    }

    private func keys(_ cells: [String]) -> [String] {
        cells.flatMap(RepoDoc.code).map { String($0.prefix { $0 != "=" }) }
    }

    private func compare(_ name: String, code: Set<String>, doc: Set<String>) -> [String] {
        code.subtracting(doc).map { "\(name) \($0): the code takes it, and PROTOCOL.md does not name it" }
            + doc.subtracting(code).map { "\(name) \($0): PROTOCOL.md names it, and the code does not take it" }
    }

    private func gaps() throws -> [String] {
        let doc = try RepoDoc("PROTOCOL.md")
        let pages = RepoDoc.tableRows(in: doc.section("Pages"))
        let headerKeys = Set(HeaderKey.allCases.map(\.rawValue) + [HeaderKey.drawing + "<size>"])
        let docHeaderKeys = keys(RepoDoc.tableRows(in: doc.section("The header")).filter { !$0[0].hasPrefix("`button") && !$0[0].hasPrefix("`field") }.map { $0[0] })
            + keys(pages.filter { $0[1] == "the header" }.map { $0[0] })

        let headerKinds = Set(HeaderBlock.allCases.map(\.rawValue))
        let docHeaderKinds = keys(RepoDoc.tableRows(in: doc.section("The header")).filter { $0[0].hasPrefix("`button") || $0[0].hasPrefix("`field") }.map { $0[0] })

        let headKeys = Set(HeadKey.allCases.map(\.rawValue) + [HeaderKey.drawing + "<size>"])
        let docHeadKeys = keys([doc.section("The head").components(separatedBy: "- The head can come")[0]])

        let docKinds = keys(RepoDoc.tableRows(in: doc.section("Blocks")).map { $0[0] })

        let rowRows = RepoDoc.tableRows(in: doc.section("Rows"))
        let docRowKeys = keys(rowRows.map { $0[0] }) + keys(rowRows.filter { $0[0] == "`push`" }.map { $0[1] }).filter { $0.hasPrefix("push.") }
            + keys(pages.filter { $0[1].contains("a row") }.map { $0[0] })

        let events = Set(SpotEvent.known + [SpotEvent.clockPrefix + "<seconds>"])
        let docEvents = keys(RepoDoc.tableRows(in: doc.section("Events")).map { $0[0] })

        let places = Set(Place.allCases.map(\.rawValue) + [Place.none, OfferedAction.place])
        let docPlaces = keys(RepoDoc.tableRows(in: doc.section("Places")).map { $0[0] })

        let uses = Set(SpotUse.allCases.map(\.rawValue))
        let docUses = keys(RepoDoc.tableRows(in: doc.section("Trust")).map { $0[0] })

        let docCalls = RepoDoc.tableRows(in: doc.section("The calls")).flatMap { RepoDoc.code($0[0]) }
            .filter { $0.hasPrefix("<spot> ") }.map { $0.split(separator: " ")[1] }.filter { !$0.hasPrefix("<") }.map(String.init)

        let variable = #"OPENSPOT_[A-Z_]*[A-Z]"#
        let scripts = try ["spots", "examples"].flatMap { folder -> [String] in
            let files = FileManager.default.enumerator(at: RepoDoc.repo.appendingPathComponent(folder), includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
            return try files.filter { ["sh", "js", "swift", "py"].contains($0.pathExtension) }.map { try String(contentsOf: $0, encoding: .utf8) }
        }
        let read = Set(scripts.flatMap { RepoDoc.matches(variable, in: $0).map { $0[0] } }.filter { !$0.hasPrefix(FieldValues.variablePrefix) })
        let core = FileManager.default.enumerator(at: RepoDoc.repo.appendingPathComponent("app/Core"), includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        let set = Set(try core.filter { $0.pathExtension == "swift" }.flatMap { RepoDoc.matches(variable, in: try String(contentsOf: $0, encoding: .utf8)).map { $0[0] } })
        let docVariables = Set(RepoDoc.matches(variable, in: doc.text).map { $0[0] }.filter { !$0.hasPrefix(FieldValues.variablePrefix) })

        let helper = try source("Shell/openspot.sh")
        let functions = Set(RepoDoc.matches(#"(?m)^([a-z][a-z_]*)\(\)"#, in: helper).map { $0[1] })
        let docFunctions = RepoDoc.tableRows(in: doc.section("The calls")).flatMap { RepoDoc.code($0[0]) }
            .map { String($0.prefix { $0 != " " }) }.filter { $0.range(of: #"^[a-z_]+$"#, options: .regularExpression) != nil }

        return compare("header key", code: headerKeys, doc: Set(docHeaderKeys))
            + compare("header block", code: headerKinds, doc: Set(docHeaderKinds))
            + compare("head key", code: headKeys, doc: Set(docHeadKeys))
            + compare("block kind", code: BlockKind.words, doc: Set(docKinds))
            + compare("row key", code: Set(RowKey.allCases.map(\.rawValue)), doc: Set(docRowKeys))
            + compare("event", code: events, doc: Set(docEvents))
            + compare("place", code: places, doc: Set(docPlaces))
            + compare("use", code: uses, doc: Set(docUses))
            + compare("call", code: Set(FrameCheck.calls), doc: Set(docCalls))
            + compare("shell helper", code: functions, doc: Set(docFunctions))
            + compare("variable", code: read.union(docVariables.intersection(set)), doc: docVariables)
    }

    func testEachKeyKindAndCallOfTheProtocolIsOneTheCodeTakesAndTheOtherWayRound() throws {
        let found = Set(try gaps())
        let listed = Set(try String(contentsOf: gapsFile, encoding: .utf8).components(separatedBy: "\n").filter { !$0.isEmpty })

        for gap in found.subtracting(listed).sorted() {
            XCTFail("\(gap). Fix the code or PROTOCOL.md.")
        }
        for gap in listed.subtracting(found).sorted() {
            XCTFail("\(gap): this gap is gone, so remove its line from scripts/protocol-gaps.txt.")
        }
    }

    func testEachOpenspotCommandThatADocNamesIsOneTheCommandTakes() throws {
        let usage = CommandLineCall.usage.components(separatedBy: "\n").filter { $0.hasPrefix("openspot ") }.map { line in
            line.split(separator: " ").prefix { !$0.hasPrefix("<") && !$0.hasPrefix("[") && !$0.hasPrefix("-") }.map(String.init)
        }
        for doc in try ["GUIDE.md", "PROTOCOL.md"].map(RepoDoc.init) + RepoDoc.all().filter({ $0.path.hasPrefix("app/Help/") }) {
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

    func testEachVerbOfTheTableIsOneThatPROTOCOLOrTheGuideOfItsNounNames() throws {
        let protocolText = try RepoDoc("PROTOCOL.md").text
        for noun in CommandNoun.all {
            let text = try protocolText + (noun.guide.map { try RepoDoc("app/Help/\($0).md").text } ?? "")
            for verb in noun.verbs where !verb.about.isEmpty {
                let phrase = ([noun.name] + verb.words).joined(separator: " ")
                let listed = text.contains("`openspot \(phrase)") || text.contains("`\(phrase)")
                    || text.contains("`openspot \(noun.name) <verb>`") && text.contains("`\(verb.words.joined(separator: " "))`")
                XCTAssertTrue(listed, "PROTOCOL.md and the guide of \(noun.name) do not name `openspot \(phrase)`")
            }
        }
    }

    func testEachStatusWordAndSourceIDThatCoreWritesIsOneTheDocsName() throws {
        let protocolText = try RepoDoc("PROTOCOL.md").text
        let screen = try RepoDoc("app/Help/screen.md").text
        for status in TranslatedText.Status.allCases.map(\.rawValue) + [CalcRateFailure.offline, .unavailable].map(\.rawValue) {
            XCTAssertTrue(protocolText.contains("`status=\(status)`"), "PROTOCOL.md does not name status=\(status)")
        }
        for state in ScreenRecording.State.allCases {
            XCTAssertTrue(screen.contains("`state=\(state.rawValue)`"), "the guide of screen does not name state=\(state.rawValue)")
        }
        for kind in ScreenDevice.Kind.allCases.map(\.rawValue) + [ScreenDevice.system] {
            XCTAssertTrue(screen.contains("`\(kind):<id>`") || screen.contains("`\(kind)`"), "the guide of screen does not name the source \(kind)")
        }
    }
}
