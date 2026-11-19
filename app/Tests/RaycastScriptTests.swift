import XCTest
@testable import OpenspotCore

final class RaycastScriptTests: XCTestCase {
    private let dock = """
    #!/bin/bash

    # Required parameters:
    # @raycast.schemaVersion 1
    # @raycast.title Dock Position
    # @raycast.mode silent

    # Optional parameters:
    # @raycast.icon 🤖
    # @raycast.argument1 { "type": "dropdown", "placeholder": "Position on Screen", "data": [{"title": "Left", "value": "left"}, {"title": "Right", "value": "right"}, {"title": "Bottom", "value": "bottom"}]  }
    # @raycast.packageName System

    # Documentation:
    # @raycast.description Set the position of the Dock in the screen
    defaults write com.apple.dock orientation -string "$1"
    """

    func testAHeaderGivesItsTitleModeIconPackageAndDescription() throws {
        let script = try RaycastScript(text: dock, name: "dock-set-position.sh")

        XCTAssertEqual(script.title, "Dock Position")
        XCTAssertEqual(script.mode, .silent)
        XCTAssertEqual(script.icon, "🤖")
        XCTAssertEqual(script.package, "System")
        XCTAssertEqual(script.description, "Set the position of the Dock in the screen")
        XCTAssertFalse(script.confirms)
    }

    func testADropdownArgumentKeepsEachOptionInOrder() throws {
        let script = try RaycastScript(text: dock, name: "dock-set-position.sh")

        XCTAssertEqual(script.arguments.count, 1)
        XCTAssertEqual(script.arguments[0].placeholder, "Position on Screen")
        XCTAssertEqual(script.arguments[0].options.map(\.value), ["left", "right", "bottom"])
        XCTAssertEqual(script.arguments[0].options.map(\.title), ["Left", "Right", "Bottom"])
    }

    func testTextArgumentsKeepWhetherTheyAreOptionalAndEncoded() throws {
        let text = """
        #!/bin/bash
        # @raycast.schemaVersion 1
        # @raycast.title Search Flights
        # @raycast.mode silent
        # @raycast.argument1 { "type": "text", "placeholder": "from city", "percentEncoded": true }
        # @raycast.argument2 { "type": "text", "placeholder": "to city", "optional": true, "percentEncoded": true }
        """

        let arguments = try RaycastScript(text: text, name: "flights.sh").arguments

        XCTAssertEqual(arguments, [
            RaycastArgument(placeholder: "from city", isEncoded: true),
            RaycastArgument(placeholder: "to city", isOptional: true, isEncoded: true)
        ])
    }

    func testASlashCommentHeaderAndConfirmationAreRead() throws {
        let text = """
        #!/usr/bin/swift

        // Required parameters:
        // @raycast.schemaVersion 1
        // @raycast.title Quit All Applications
        // @raycast.mode silent
        // @raycast.needsConfirmation true
        import Cocoa
        """

        let script = try RaycastScript(text: text, name: "quit-all-apps.swift")

        XCTAssertEqual(script.title, "Quit All Applications")
        XCTAssertTrue(script.confirms)
    }

    func testAnInlineScriptRefreshesAtItsTimeAndAMarkdownLinkBecomesItsText() throws {
        let text = """
        #!/bin/bash
        # @raycast.title Current Weather
        # @raycast.description Get current weather report from [wttr.in](https://wttr.in/).
        # @raycast.icon 🌦️
        # @raycast.mode inline
        # @raycast.schemaVersion 1
        # @raycast.refreshTime 1h
        """

        let script = try RaycastScript(text: text, name: "current-weather.sh")

        XCTAssertEqual(script.mode, .inline)
        XCTAssertEqual(script.refreshSeconds, 3600)
        XCTAssertEqual(script.description, "Get current weather report from wttr.in.")
    }

    func testAnInlineScriptWithNoRefreshTimeRunsAsCompactAsInRaycast() throws {
        let text = "#!/bin/bash\n# @raycast.schemaVersion 1\n# @raycast.title Load\n# @raycast.mode inline\n"

        let script = try RaycastScript(text: text, name: "load.sh")

        XCTAssertEqual(script.mode, .compact)
        XCTAssertNil(script.refreshSeconds)
    }

    func testARefreshTimeUnderTenSecondsWaitsTenSeconds() throws {
        let text = "#!/bin/bash\n# @raycast.schemaVersion 1\n# @raycast.title Tick\n# @raycast.mode inline\n# @raycast.refreshTime 2s\n"

        XCTAssertEqual(try RaycastScript(text: text, name: "tick.sh").refreshSeconds, 10)
    }

    func testAFileThatIsNotAScriptCommandIsSkippedWithItsReason() {
        XCTAssertThrowsError(try RaycastScript(text: "#!/bin/bash\necho hi\n", name: "hi.sh")) { XCTAssertEqual($0 as? RaycastScript.Skip, .notScript) }
        XCTAssertThrowsError(try RaycastScript(text: "# @raycast.title A\n# @raycast.mode silent\n", name: "a.md")) { XCTAssertEqual($0 as? RaycastScript.Skip, .notScript) }
        XCTAssertThrowsError(try RaycastScript(text: dock, name: "dock.template.sh")) { XCTAssertEqual($0 as? RaycastScript.Skip, .template) }
        XCTAssertThrowsError(try RaycastScript(text: dock.replacingOccurrences(of: "schemaVersion 1", with: "schemaVersion 2"), name: "dock.sh")) {
            XCTAssertEqual($0 as? RaycastScript.Skip, .schema("2"))
        }
        XCTAssertThrowsError(try RaycastScript(text: dock.replacingOccurrences(of: "mode silent", with: "mode loud"), name: "dock.sh")) {
            XCTAssertEqual($0 as? RaycastScript.Skip, .mode("loud"))
        }
    }
}
