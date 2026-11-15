import XCTest

final class DocReferenceTests: XCTestCase {
    private let repo = RepoDoc.repo

    private func exists(_ path: String, in folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path)
    }

    func testEachLinkOfADocReachesAFileAndAHeadingThatExist() throws {
        for doc in try RepoDoc.all() {
            let links = RepoDoc.matches(#"\]\(([^)\s]+)\)"#, in: doc.prose) + RepoDoc.matches(#"(?:href|src)="([^"]+)""#, in: doc.prose)
            for link in links.map({ $0[1] }) where !link.contains("://") && !link.hasPrefix("mailto:") {
                let parts = link.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
                let file = parts[0]
                XCTAssertTrue(file.isEmpty || exists(file, in: doc.folder), "\(doc.path) links to \(file), which does not exist")
                guard parts.count == 2 else { continue }
                let target = file.isEmpty ? doc : try? RepoDoc(doc.folder.appendingPathComponent(file).path.replacingOccurrences(of: repo.path + "/", with: ""))
                XCTAssertTrue(target?.anchors.contains(parts[1]) == true, "\(doc.path) links to \(link), a heading that does not exist")
            }
        }
    }

    func testEachProtocolCitationNamesAHeadingOfTheProtocol() throws {
        let headings = Set(try RepoDoc("PROTOCOL.md").headings)
        let kinds: Set<String> = ["swift", "sh", "js", "md", "py", "toml", "yml"]
        let skipped: Set<String> = [".git", ".temp", ".claude", "plans", "Openspot.xcodeproj", "build"]
        let walk = try XCTUnwrap(FileManager.default.enumerator(at: repo, includingPropertiesForKeys: nil))
        var cited = 0
        for case let url as URL in walk {
            if skipped.contains(url.lastPathComponent) { walk.skipDescendants(); continue }
            guard kinds.contains(url.pathExtension), let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for match in RepoDoc.matches(#"\((p)rotocol: ([^)]+)\)"#, in: text) {
                for name in match[2].components(separatedBy: ", ") {
                    cited += 1
                    XCTAssertTrue(headings.contains(name), "\(url.path.replacingOccurrences(of: repo.path + "/", with: "")) cites the protocol heading \(name), which PROTOCOL.md lacks")
                }
            }
        }
        XCTAssertGreaterThan(cited, 0)
    }

    func testEachPathThatADocNamesInTheRepoExists() throws {
        let ignored = try String(contentsOf: repo.appendingPathComponent(".gitignore"), encoding: .utf8)
            .components(separatedBy: "\n").filter { $0.hasSuffix("/") && !$0.contains("*") }.map { String($0.dropLast()) }
        let bases = [repo, repo.appendingPathComponent("app")]
        for doc in try RepoDoc.all() {
            for path in RepoDoc.matches("`([^`\\s]+)`", in: doc.prose).map({ $0[1] }) {
                if path.range(of: #"^[A-Z]+\.md$"#, options: .regularExpression) != nil {
                    XCTAssertTrue(bases.contains { exists(path, in: $0) }, "\(doc.path) names \(path), which does not exist")
                    continue
                }
                guard path.contains("/"), !path.contains("*"), !path.contains("<"), !path.contains(":") else { continue }
                let first = String(path.prefix { $0 != "/" })
                guard !first.isEmpty, first != ".", !ignored.contains(first) else { continue }
                var isFolder: ObjCBool = false
                let named = bases.filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent(first).path, isDirectory: &isFolder) && isFolder.boolValue }
                guard !named.isEmpty else { continue }
                XCTAssertTrue(named.contains { exists(path, in: $0) }, "\(doc.path) names \(path), which does not exist")
            }
        }
    }

    func testEachMakeTargetThatADocNamesIsInTheMakefile() throws {
        let makefile = try String(contentsOf: repo.appendingPathComponent("Makefile"), encoding: .utf8)
        let targets = Set(RepoDoc.matches(#"(?m)^([a-z][a-z-]*):"#, in: makefile).map { $0[1] })
        for doc in try RepoDoc.all() {
            let named = RepoDoc.matches(#"`make ([a-z][a-z-]*)"#, in: doc.prose) + doc.fences.flatMap { RepoDoc.matches(#"(?m)^make ([a-z][a-z-]*)"#, in: $0.text) }
            for target in named.map({ $0[1] }) {
                XCTAssertTrue(targets.contains(target), "\(doc.path) names make \(target), which the Makefile lacks")
            }
        }
    }
}
