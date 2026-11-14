import XCTest
@testable import OpenspotCore

final class ProtocolContractTests: XCTestCase {
    private let gapsFile = RepoDoc.repo.appendingPathComponent("scripts/protocol-gaps.txt")

    private func source(_ path: String) throws -> String {
        try String(contentsOf: RepoDoc.repo.appendingPathComponent("app/\(path)"), encoding: .utf8)
    }

    private func literals(in text: String) -> [String] {
        RepoDoc.matches(#""([^"\\\n]*)""#, in: text).map { $0[1] }
    }

    private func line(_ marker: String, in text: String) -> String {
        text.components(separatedBy: "\n").first { $0.contains(marker) } ?? ""
    }

    private func keys(_ cells: [String]) -> [String] {
        cells.flatMap(RepoDoc.code).map { String($0.prefix { $0 != "=" }) }
    }

    private func refused(_ header: String) -> Bool {
        do {
            _ = try SpotFile(script: URL(fileURLWithPath: "/none/probe.sh"), header: SpotHeader(text: "#!/bin/sh\n# title=T\n# on=sheet.open\n" + header).block, id: "probe")
            return false
        } catch {
            return (error as? SpotError)?.reason.contains("no longer reads") ?? false
        }
    }

    private func loads(_ header: String) -> Bool {
        (try? SpotFile(script: URL(fileURLWithPath: "/none/probe.sh"), header: SpotHeader(text: "#!/bin/sh\n# title=T\n# on=sheet.open\n" + header).block, id: "probe")) != nil
    }

    private func isKind(_ word: String) -> Bool {
        let block = word == "option" ? "choice=c\n\noption=x\ntitle=X\n" : "\(word)=x\ntitle=X\n"
        let output = SpotOutput(text: block)
        return output.summary == nil && output.errors.isEmpty && output.retired.isEmpty
    }

    private func isCallWord(_ word: String) -> Bool {
        SpotOutput(text: "row=r\nfile=/r\n\nswitch=\(word)\ntitle=X\n").partFaults.contains("a part cannot be called \(word)")
    }

    private func rowMoves(_ key: String) -> Bool {
        let base = key.hasPrefix("push.") ? "row=r\npush=p\n" : "row=r\n"
        func move(_ text: String) -> FlowMove? {
            TextBlock.blocks(in: text).first.flatMap(SpotItem.init(block:))?.move
        }
        return move(base + "\(key)=true\n") != move(base)
    }

    private func compare(_ name: String, code: Set<String>, doc: Set<String>) -> [String] {
        code.subtracting(doc).map { "\(name) \($0): the code takes it, and PROTOCOL.md does not name it" }
            + doc.subtracting(code).map { "\(name) \($0): PROTOCOL.md names it, and the code does not take it" }
    }

    private func gaps() throws -> [String] {
        let doc = try RepoDoc("PROTOCOL.md")
        let spotFile = try source("Core/Spot/SpotFile.swift")
        let headerReads = Set(RepoDoc.matches(#"header\.(?:value|values|list)\("([^"]+)"\)"#, in: spotFile).map { $0[1] })
        let prefix = literals(in: line("drawingPrefix = ", in: spotFile)).map { $0 + "<size>" }
        let headerKeys = headerReads.filter { !refused("# \($0)=1\n") }.union(prefix)
        let pages = RepoDoc.tableRows(in: doc.section("Pages"))
        let docHeaderKeys = keys(RepoDoc.tableRows(in: doc.section("The header")).filter { !$0[0].hasPrefix("`button") && !$0[0].hasPrefix("`field") }.map { $0[0] })
            + keys(pages.filter { $0[1] == "the header" }.map { $0[0] })

        let headerKinds = Set(literals(in: line("kinds: Set<String> = ", in: try source("Core/Spot/SpotHeader.swift"))))
            .filter { !refused("#\n# \($0)=x\n# title=X\n") }
        let docHeaderKinds = keys(RepoDoc.tableRows(in: doc.section("The header")).filter { $0[0].hasPrefix("`button") || $0[0].hasPrefix("`field") }.map { $0[0] })

        let output = try source("Core/Script/SpotOutput.swift")
        let headKeys = Set(literals(in: line("headKeys: Set<String> = ", in: output))).union(prefix)
        let docHeadKeys = keys([doc.section("The head").components(separatedBy: "- The head can come")[0]])

        let docKinds = keys(RepoDoc.tableRows(in: doc.section("Blocks")).map { $0[0] })
        let candidates = Set(SpotPart.kinds + literals(in: output) + docKinds).filter { $0.range(of: #"^[a-z]+$"#, options: .regularExpression) != nil }
        let kinds = candidates.filter(isKind)

        let reads = #"block\.(?:value|values|flag|list|number)\("([^"]+)"\)"#
        let itemReads = RepoDoc.matches(reads, in: try source("Core/Spot/SpotItem.swift")).map { $0[1] }
            + RepoDoc.matches(reads, in: try source("Core/Flow/FlowMove.swift")).map { $0[1] }.filter(rowMoves)
        let rowRows = RepoDoc.tableRows(in: doc.section("Rows"))
        let docRowKeys = keys(rowRows.map { $0[0] }) + keys(rowRows.filter { $0[0] == "`push`" }.map { $0[1] }).filter { $0.hasPrefix("push.") }
            + keys(pages.filter { $0[1].contains("a row") }.map { $0[0] })

        let events = Set(SpotEvent.known + [SpotEvent.clockPrefix + "<seconds>"])
        let docEvents = keys(RepoDoc.tableRows(in: doc.section("Events")).map { $0[0] })

        let placeWords = Set(Place.allCases.map(\.rawValue) + literals(in: try source("Core/Spot/Place.swift")))
            .filter { $0.range(of: #"^[a-z]+$"#, options: .regularExpression) != nil }
        let docPlaces = keys(RepoDoc.tableRows(in: doc.section("Places")).map { $0[0] })
        let places = placeWords.union(docPlaces).filter { word in
            Place(rawValue: word) != nil || loads("# offers=\(word)\n") || loads("#\n# button=b\n# title=B\n# offers=\(word)\n")
        }

        let uses = Set(SpotUse.allCases.map(\.rawValue))
        let docUses = keys(RepoDoc.tableRows(in: doc.section("Trust")).map { $0[0] })

        let docCalls = RepoDoc.tableRows(in: doc.section("The calls")).flatMap { RepoDoc.code($0[0]) }
            .filter { $0.hasPrefix("<spot> ") }.map { $0.split(separator: " ")[1] }.filter { !$0.hasPrefix("<") }.map(String.init)
        let calls = Set(literals(in: output) + docCalls).filter { $0.range(of: #"^[a-z]+$"#, options: .regularExpression) != nil }.filter(isCallWord)

        let helper = try source("Shell/openspot.sh")
        let functions = Set(RepoDoc.matches(#"(?m)^([a-z][a-z_]*)\(\)"#, in: helper).map { $0[1] })
        let docFunctions = RepoDoc.tableRows(in: doc.section("The calls")).flatMap { RepoDoc.code($0[0]) }
            .map { String($0.prefix { $0 != " " }) }.filter { $0.range(of: #"^[a-z_]+$"#, options: .regularExpression) != nil }

        return compare("header key", code: headerKeys, doc: Set(docHeaderKeys))
            + compare("header block", code: headerKinds, doc: Set(docHeaderKinds))
            + compare("head key", code: headKeys, doc: Set(docHeadKeys))
            + compare("block kind", code: kinds, doc: Set(docKinds))
            + compare("row key", code: Set(itemReads), doc: Set(docRowKeys))
            + compare("event", code: events, doc: Set(docEvents))
            + compare("place", code: places, doc: Set(docPlaces))
            + compare("use", code: uses, doc: Set(docUses))
            + compare("call", code: calls, doc: Set(docCalls))
            + compare("shell helper", code: functions, doc: Set(docFunctions))
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
                let parsed: Bool
                switch CommandLineCall(arguments: Array(words.dropFirst()), environment: [:]) {
                case .unknown(_)?, nil: parsed = false
                default: parsed = true
                }
                let literal = command.split(separator: " ").prefix { !$0.hasPrefix("<") && !$0.hasPrefix("[") && !$0.hasPrefix("-") }.map(String.init)
                let named = usage.contains { form in
                    form.count >= literal.count && zip(form, literal).allSatisfy { pair in pair.0.split(separator: "|").contains { $0 == pair.1 } }
                }
                XCTAssertTrue(parsed || named, "\(doc.path) names `\(command)`, which openspot does not take")
            }
        }
    }
}
