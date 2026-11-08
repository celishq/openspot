import XCTest
@testable import OpenspotCore

/// Proves the System Settings plugin with its real script, a folder of fake panes and a fake language list.
final class SettingsPluginTests: SamplePluginsCase {
    func testSystemSettingsJoinsTheMainSearch() throws {
        let settings = try XCTUnwrap(try scan.commands.first { $0.name == "System Settings" })

        XCTAssertTrue(settings.isGlobal)
    }

    func testAPaneAndItsSectionsAreRowsInTheLanguageOfTheMac() async throws {
        try await withPanes { home in
            let panes = home.appendingPathComponent("panes")
            let rows = try await self.rows()

            let pane = try XCTUnwrap(rows.first { $0.title == "Звук" })
            XCTAssertEqual(pane.subtitle, "System Settings")
            XCTAssertEqual(pane.file, panes.appendingPathComponent("Sound.appex").path)
            let section = try XCTUnwrap(rows.first { $0.title == "Громкость" })
            XCTAssertEqual(section.subtitle, "System Settings › Звук")
            XCTAssertEqual(section.keywords, ["громко", "тихо"])
            XCTAssertEqual(section.file, pane.file)
            XCTAssertEqual(pane.badge, .file("/System/Applications/System Settings.app"))
            XCTAssertEqual(section.badge, pane.badge)
        }
    }

    func testAPaneWithACodeNameTakesTheNamesOfItsSidebarAndASymbol() async throws {
        try await withPanes { _ in
            let rows = try await self.rows()

            XCTAssertEqual(rows.filter { $0.subtitle == "System Settings" }.map(\.title).sorted(), ["Аккумулятор", "Звук", "Энергия"])
            let battery = try XCTUnwrap(rows.first { $0.title == "Аккумулятор" })
            XCTAssertNil(battery.file)
            XCTAssertEqual(battery.symbol, "gearshape")
        }
    }

    func testAPickOpensTheSectionOfItsPane() async throws {
        try await withPanes { home in
            let settings = try XCTUnwrap(try self.scan.commands.first { $0.name == "System Settings" })
            let rows = try await self.rows()
            let section = try XCTUnwrap(rows.first { $0.title == "Громкость" })

            _ = try await settings.perform(.item(section), timeout: 5)

            let opened = try String(contentsOf: home.appendingPathComponent("opened"), encoding: .utf8)
            XCTAssertEqual(opened, "x-apple.systempreferences:com.apple.Sound-Settings.extension?volume\n")
        }
    }

    private func rows() async throws -> [SpotItem] {
        let settings = try XCTUnwrap(try scan.commands.first { $0.name == "System Settings" })
        let output = try await settings.items(timeout: 10)
        XCTAssertEqual(output.errors, [])
        return output.items
    }

    /// Runs in a private home, which it passes, with a Sound pane, a Battery pane known only by its code name, a pane with no name and an
    /// extension that is not a pane. The Mac's first language is Russian.
    private func withPanes(_ body: @escaping (URL) async throws -> Void) async throws {
        try await withPrivateHome { folder in
            let panes = folder.appendingPathComponent("panes")
            try Self.pane("Sound", in: panes, info: ["CFBundleIdentifier": "com.apple.Sound-Settings.extension", "CFBundleName": "Sound", "CFBundleIcons": [:]],
                          names: ["en": ["CFBundleDisplayName": "Sound"], "ru": ["CFBundleDisplayName": "Звук"]],
                          terms: ["ru": ["volume": ["localizableStrings": [["title": "Громкость", "index": "громко, тихо"]]]]])
            try Self.pane("PowerPreferences", in: panes, info: [
                "CFBundleIdentifier": "com.apple.Battery-Settings.extension", "CFBundleName": "PowerPreferences", "CFBundleDisplayName": "PowerPreferences",
                "Sidebar": [["sidebar-name": "ENERGY", "predicate": "battery != YES"], ["sidebar-name": "BATTERY", "predicate": "battery == YES"]]
            ], strings: ["ru": ["BATTERY": "Аккумулятор", "ENERGY": "Энергия"]])
            try Self.pane("HeadphoneSettingsExtension", in: panes, info: ["CFBundleIdentifier": "com.apple.HeadphoneSettings", "CFBundleDisplayName": "HeadphoneSettingsExtension"])
            try Self.pane("Widget", in: panes, info: ["CFBundleIdentifier": "com.apple.Widget", "CFBundleDisplayName": "Widget"], point: "com.apple.widgetkit-extension")
            try "#!/bin/sh\nprintf '(\\n    \"ru-RU\",\\n    en\\n)\\n'\n".writeScript(to: folder.appendingPathComponent("tools/defaults"))
            setenv("SETTINGS_PANES", panes.path, 1)
            defer { unsetenv("SETTINGS_PANES") }
            try await body(folder)
        }
    }

    private static func pane(_ name: String, in folder: URL, info: [String: Any], names: [String: Any]? = nil, strings: [String: Any]? = nil,
                             terms: [String: [String: Any]] = [:], point: String = "com.apple.Settings.extension.ui") throws {
        let contents = folder.appendingPathComponent("\(name).appex/Contents")
        let resources = contents.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        var info = info
        info["EXAppExtensionAttributes"] = ["EXExtensionPointIdentifier": point]
        try write(info, to: contents.appendingPathComponent("Info.plist"))
        if let names { try write(names, to: resources.appendingPathComponent("InfoPlist.loctable")) }
        if let strings { try write(strings, to: resources.appendingPathComponent("Localizable.loctable")) }
        for (language, table) in terms {
            let lproj = resources.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
            try write(table, to: lproj.appendingPathComponent("\(name).searchTerms"))
        }
    }

    private static func write(_ value: Any, to url: URL) throws {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0).write(to: url)
    }
}
