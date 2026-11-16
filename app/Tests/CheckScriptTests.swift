import XCTest

final class CheckScriptTests: XCTestCase {
    private static let checks = ["core", "tests", "comments", "motion", "names", "files", "getters", "spots", "processes", "glass", "shapes", "tools"]
    private static let lists = ["names", "files", "getters", "test-pauses", "spot-clocks", "spot-state", "processes", "shapes"]

    private static let breaches: [(check: String, file: String, text: String)] = [
        ("core", "app/Core/Panel.swift", "@preconcurrency import AppKit\n"),
        ("core", "app/Core/Panel.swift", "import EventKit\n"),
        ("tests", "app/Tests/PanelTests.swift", "let text = NSPasteboard" + ".general.string(forType: .string)\n"),
        ("tests", "app/Tests/PanelTests.swift", "try await Task" + ".sleep(for: .seconds(1))\n"),
        ("tests", "app/Tests/PanelTests.swift", "set" + "env(\"HOME\", \"/tmp\", 1)\n"),
        ("comments", "app/Core/Panel.swift", "struct Panel {}\n// a note\n"),
        ("comments", "scripts/build.sh", "#!/bin/sh\n# a note\necho\n"),
        ("motion", "app/Shell/Panel.swift", "withAnimation(." + "spring(duration: 0.3)) {}\n"),
        ("motion", "app/Shell/Panel.swift", "content.opacity(isShown ? 1 " + ": 0)\n"),
        ("motion", "app/Shell/Panel.swift", "content.opacity(model.isEditing ? 0 " + ": 1)\n"),
        ("names", "app/Core/PanelManager.swift", "struct PanelManager {}\n"),
        ("files", "app/Core/Panel.swift", "struct Sheet {}\n"),
        ("files", "app/Core/Panel.swift", "struct Panel {}\nstruct Sheet {}\n"),
        ("getters", "app/Core/Panel.swift", "struct Panel {\n    var text: String {\n        (try? String(contentsOfFile: \"/a\", encoding: .utf8)) ?? \"\"\n    }\n}\n"),
        ("getters", "app/Core/Panel.swift", "struct Panel {\n    var isOn: Bool { FileManager.default.fileExists(atPath: \"/a\") }\n}\n"),
        ("getters", "app/Shell/Panel.swift", "struct Panel {\n    static func open(_ file: URL) -> Panel? {\n        guard FileManager.default.fileExists(atPath: file.path) else { return nil }\n        return Panel()\n    }\n}\n"),
        ("processes", "app/Shell/Panel.swift", "let process = Process()\n"),
        ("glass", "app/Shell/Panel.swift", "let blur = NSVisual" + "EffectView()\n"),
        ("glass", "app/Shell/Panel.swift", "let part = layers.first { $0.name == \"back" + "drop\" }\n"),
        ("glass", "app/Shell/Panel.swift", "let filter = NSClassFromString(\"CA" + "Filter\")\n"),
        ("glass", "app/Shell/Panel.swift", "part.setValue(24, forKeyPath: \"filters.gaussian" + "Blur.inputRadius\")\n"),
        ("glass", "app/Shell/Picture/PanelPicture.swift", "view.cache" + "Display(in: view.bounds, to: bitmap)\n"),
        ("glass", "app/Shell/Surface/SpotGlass.swift", "let blur = NSVisual" + "EffectView()\n"),
        ("glass", "app/Shell/Grid/SpotGridView.swift", "SpotMenuFocus(shade: model.grid" + "Shade)\n"),
        ("glass", "app/Shell/Field/SpotFieldView.swift", "let dims = model.grid" + "Shade.isOn\n"),
        ("glass", "app/Shell/Surface/SpotFocusLook.swift", "content.environment(\\.spot" + "Fade, 0.35)\n"),
        ("shapes", "app/Shell/Panel.swift", "let edge = Rounded" + "Rectangle(cornerRadius: 8, style: .continuous)\n"),
        ("shapes", "app/Shell/Grid/Card.swift", "content.overlay(Rounded" + "Rectangle(cornerRadius: SpotTokens.radius).strokeBorder(.red))\n"),
        ("tools", "app/Shell/Panel.swift", "let output = environment[\"OPENSPOT_" + "PROBE\"]\n"),
        ("tools", "app/Shell/Panel.swift", "#if OPENSPOT_TOOLS\n#if DEBUG\n#endif\n#endif\nlet probe = SpotMotion" + "Probe()\n"),
        ("tools", "app/Core/Panel.swift", "let probe = SpotMotion" + "Probe()\n"),
        ("tools", "scripts/release.sh", "xcodebuild -configuration Release SWIFT_ACTIVE_COMPILATION_CONDITIONS=OPENSPOT_" + "TOOLS build\n"),
        ("tools", "app/project.yml", "targets:\n  A:\n    configs:\n      Release:\n        SWIFT_ACTIVE_COMPILATION_CONDITIONS: OPENSPOT_" + "TOOLS\n"),
        ("processes", "app/Client/main.swift", "_ = posix_spawn(&started, path, nil, nil, words, environ)\n"),
        ("spots", "spots/weather.spot/weather.sh", "#!/bin/sh\n# title=Weather\n# on=clock.5\necho\n"),
        ("spots", "examples/weather.spot/weather.sh", "#!/bin/sh\n# title=Weather\necho 1 > \"${TMPDIR:-/tmp}/weather\"\n")
    ]

    private var scripts: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("scripts")
    }

    private func cleanTree() throws -> URL {
        let root = try temporaryFolder()
        for folder in ["app/Core", "app/Shell", "app/Client", "app/Tests", "scripts/breaks", "spots", "examples"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        for list in Self.lists {
            try "".write(to: root.appendingPathComponent("scripts/breaks/\(list).txt"), atomically: true, encoding: .utf8)
        }
        try "verify:\n\tsh scripts/check-core.sh\n".write(to: root.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)
        try "struct Clean {}\n".write(to: root.appendingPathComponent("app/Core/Clean.swift"), atomically: true, encoding: .utf8)
        return root
    }

    private func status(of check: String, in root: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scripts.appendingPathComponent("check-\(check).sh").path, root.path]
        process.currentDirectoryURL = try temporaryFolder()
        process.environment = ["PATH": "/usr/bin:/bin"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    func testEachCheckPassesOnACleanTreeFromAnotherFolder() throws {
        let root = try cleanTree()

        for check in Self.checks {
            XCTAssertEqual(try status(of: check, in: root), 0, check)
        }
    }

    func testEachCheckFailsOnEachOfItsBreaches() throws {
        for breach in Self.breaches {
            let root = try cleanTree()
            let file = root.appendingPathComponent(breach.file)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try breach.text.write(to: file, atomically: true, encoding: .utf8)

            XCTAssertEqual(try status(of: breach.check, in: root), 1, "\(breach.check): \(breach.text)")
        }
    }

    func testACheckWithATrackedListFailsOnAListedBreakThatIsGone() throws {
        for list in Self.lists {
            let root = try cleanTree()
            try "app/Core/Gone.swift\n".write(to: root.appendingPathComponent("scripts/breaks/\(list).txt"), atomically: true, encoding: .utf8)
            let check = list.hasPrefix("spot") ? "spots" : list == "test-pauses" ? "tests" : list

            XCTAssertEqual(try status(of: check, in: root), 1, list)
        }
    }

    func testACheckPassesOnABreakThatItsListHolds() throws {
        let root = try cleanTree()
        try "struct PanelManager {}\n".write(to: root.appendingPathComponent("app/Core/PanelManager.swift"), atomically: true, encoding: .utf8)
        try "app/Core/PanelManager.swift\tPanelManager\n".write(to: root.appendingPathComponent("scripts/breaks/names.txt"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try status(of: "names", in: root), 0)
    }

    func testTheGlassCheckPassesOnAPictureFileThatTurnsSystemGlassOff() throws {
        let root = try cleanTree()
        let file = root.appendingPathComponent("app/Shell/Picture/PanelPicture.swift")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ("content.environment(\\.spotDrawsGlass, false)\nview.cache" + "Display(in: view.bounds, to: bitmap)\n").write(to: file, atomically: true, encoding: .utf8)

        XCTAssertEqual(try status(of: "glass", in: root), 0)
    }

    func testTheGlassCheckAllowsThePrivateBlurInTheBackdropFileAlone() throws {
        let root = try cleanTree()
        let file = root.appendingPathComponent("app/Shell/Surface/SpotBackdropBlur.swift")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ("let blur = NSVisual" + "EffectView()\nlet filter = NSClassFromString(\"CA" + "Filter\")\n").write(to: file, atomically: true, encoding: .utf8)

        XCTAssertEqual(try status(of: "glass", in: root), 0)
    }

    func testTheShapesCheckAllowsARoundedRectangleInTheOneShapeFileAlone() throws {
        let root = try cleanTree()
        let file = root.appendingPathComponent("app/Shell/Surface/SpotRoundShape.swift")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ("Rounded" + "Rectangle(cornerRadius: 8).path(in: rect)\n").write(to: file, atomically: true, encoding: .utf8)

        XCTAssertEqual(try status(of: "shapes", in: root), 0)
    }

    func testEachCheckFailsWhenAFolderItScansIsMissing() throws {
        let root = try temporaryFolder()

        for check in Self.checks {
            XCTAssertEqual(try status(of: check, in: root), 1, check)
        }
    }
}
