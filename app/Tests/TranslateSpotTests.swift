import XCTest
@testable import OpenspotCore

final class TranslateSpotTests: SampleSpotsCase {
    func testTranslateShowsItsPartsBeforeItKnowsItsLanguages() async throws {
        try await withPrivateHome { folder in
            _ = try self.fakeTranslate(in: folder)
            let tool = folder.appendingPathComponent("tools/openspot")
            let fake = try String(contentsOf: tool, encoding: .utf8)
            let release = folder.appendingPathComponent("release")
            let wait = "n=0; while [ ! -f '\(release.path)' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done"
            try fake.replacingOccurrences(of: "if [ \"$2\" = languages ]; then", with: "if [ \"$2\" = languages ]; then\n  \(wait)").writeScript(to: tool)
            let translate = try XCTUnwrap(try self.scan.spots.first { $0.name == "Translate" })

            let options = try await Self.targetOptions(of: translate, release: release)

            XCTAssertLessThan(options.first, 2)
            XCTAssertEqual(options.last, 2)
        }
    }

    func testTranslateIsASheetOfPartsWithItsLanguagesAndNoFaults() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await translate.items(timeout: 60)

            XCTAssertEqual(translate.mode, .once)
            XCTAssertTrue(translate.hasSheet)
            XCTAssertEqual(translate.kind, .list)
            XCTAssertEqual(output.kind, .list)
            let faults = try await translate.sheetFaults(timeout: 60)
            XCTAssertEqual(faults, [])
            XCTAssertEqual(output.tree.children, ["pair"])
            XCTAssertEqual(output.tree.node("pair")?.children, ["top", "seam", "bottom"])
            XCTAssertEqual(output.tree.node("seam")?.style.isAbsolute, true)
            XCTAssertEqual(output.tree.node("swap")?.parent, "seam")
            XCTAssertEqual(output.tree.node("swap")?.style.blursBackdrop, true)
            XCTAssertEqual(output.tree.node("swap")?.style.corner, .full)
            XCTAssertEqual(output.parts.map(\.id), ["source", "input", "swap", "target", "output"])
            XCTAssertEqual(self.text(of: "source", in: output), "auto")
            XCTAssertEqual(self.text(of: "target", in: output), "en")
        }
    }

    func testTranslateAnswersTypedTextAndOffersToCopy() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await Self.drive(translate, [("source", "ru"), ("target", "en"), ("input", "hi")])

            XCTAssertEqual(self.text(of: "output", in: output), "HI")
            XCTAssertEqual(output.parts.last?.id, "copy")
            XCTAssertEqual(output.parts.last?.key, ActionKey(name: "return", isCommand: true))
        }
    }

    func testTranslateTakesTheTextOfASlashCommandAsItsInput() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)
            let output = try await Self.answer(of: translate, "command", input: "input.source=ru\ninput.target=en\ninput.name=translate\ninput.text=hi\n")

            XCTAssertEqual(self.text(of: "input", in: output), "hi")
        }
    }

    func testTheTextOfASlashCommandReplacesTheTextInTheField() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)
            let output = try await Self.answer(of: translate, "command", input: "input.source=ru\ninput.target=en\ninput.input=old\ninput.name=translate\ninput.text=new\n")

            XCTAssertEqual(self.text(of: "input", in: output), "new")
        }
    }

    func testTranslateMovesItsTargetWhenTheTextIsAlreadyInIt() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await Self.drive(translate, [("input", "hi")])

            XCTAssertEqual(self.text(of: "target", in: output), "ru")
        }
    }

    func testTranslateSwapsTheLanguagesAndTheTexts() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await Self.drive(translate, [("source", "ru"), ("target", "en"), ("input", "hi"), ("swap", nil)])

            XCTAssertEqual(self.text(of: "source", in: output), "en")
            XCTAssertEqual(self.text(of: "target", in: output), "ru")
            XCTAssertEqual(self.text(of: "input", in: output), "HI")
        }
    }

    func testTranslateKeepsTheChosenLanguagesForTheNextRead() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            _ = try await Self.drive(translate, [("source", "en"), ("target", "ru")])
            let output = try await translate.items(timeout: 60)

            XCTAssertEqual(self.text(of: "source", in: output), "en")
            XCTAssertEqual(self.text(of: "target", in: output), "ru")
        }
    }

    func testTranslateLinksToSettingsWhenALanguageIsMissing() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder, status: "missing")

            let output = try await Self.drive(translate, [("input", "привет")])

            XCTAssertEqual(self.text(of: "output", in: output), "Russian to English is not installed")
            XCTAssertEqual(output.parts.last?.id, "settings")
        }
    }

    func testTranslateCopiesItsOutput() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await Self.drive(translate, [("source", "ru"), ("target", "en"), ("input", "one\ntwo"), ("copy", nil)])

            XCTAssertNil(output.root?.value("toast"))
            XCTAssertEqual(self.toasts(in: folder), ["Copied"])
            XCTAssertEqual(try self.read("clipboard", in: folder), "OnE\nTWO")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("direct").path))
        }
    }

    func testTranslateShowsNoTextOnANewOpenAndKeepsItsLanguages() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            _ = try await Self.drive(translate, [("source", "en"), ("target", "ru"), ("input", "hi")])
            let output = try await translate.items(timeout: 60)

            XCTAssertEqual(self.text(of: "input", in: output), "")
            XCTAssertEqual(self.text(of: "output", in: output), "")
            XCTAssertEqual(self.text(of: "source", in: output), "en")
            XCTAssertEqual(self.text(of: "target", in: output), "ru")
        }
    }

    func testTranslateTakesABigPaste() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)
            let big = String(repeating: String(repeating: "a", count: 99) + "\\", count: 10_000)

            let output = try await Self.drive(translate, [("source", "ru"), ("target", "en"), ("input", big)])

            XCTAssertEqual(self.text(of: "output", in: output), big.uppercased())
        }
    }

    func testTranslateShowsTheMessageOfACommandThatFails() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)
            let tool = folder.appendingPathComponent("tools/openspot")
            let working = try String(contentsOf: tool, encoding: .utf8)
            _ = try await translate.items(timeout: 60)
            try "#!/bin/sh\ncat >/dev/null\necho 'could not start. Run it again.' >&2\nexit 1\n".write(to: tool, atomically: true, encoding: .utf8)
            defer { try? working.write(to: tool, atomically: true, encoding: .utf8) }

            let output = try await Self.drive(translate, [("input", "hi")])

            XCTAssertEqual(self.text(of: "output", in: output), "could not start. Run it again.")
            XCTAssertEqual(self.text(of: "input", in: output), "hi")
            XCTAssertEqual(output.parts.last?.id, "output")
        }
    }
}
