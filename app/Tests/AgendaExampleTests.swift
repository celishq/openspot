import XCTest
@testable import OpenspotCore

/// Proves the Agenda example with its real script and a stand-in for the openspot command, which logs each call with its
/// reason and its stdin.
final class AgendaExampleTests: SamplePluginsCase {
    private var examples: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("examples")
    }

    private func example(_ name: String) throws -> Spot {
        try XCTUnwrap(try PluginFolder(url: examples).scan().commands.first { $0.name == name })
    }

    /// A time from now in ISO 8601 with the offset of the zone, as `openspot calendar events` prints it.
    private func iso(_ seconds: TimeInterval) -> String {
        let format = ISO8601DateFormatter()
        format.timeZone = .current
        return format.string(from: Date().addingTimeInterval(seconds))
    }

    /// A stand-in for the openspot command that answers each list from a file of the folder, keeps settings in files, and
    /// adds a line to `calls` for each call: its reason, its words and its stdin.
    private func fakeOpenspot(in folder: URL) throws {
        let path = folder.path
        try """
        #!/bin/sh
        input=$(cat)
        printf '%s|%s|%s\\n' "${OPENSPOT_REASON:-act}" "$*" "$input" >> '\(path)/calls'
        key=$3
        [ "$3" = --spot ] && key=$5
        case "$1 $2" in
          'setting get') cat "\(path)/setting-$key" 2>/dev/null ;;
          'setting set') if [ $# -ge 4 ]; then printf '%s' "$4" > "\(path)/setting-$3"; else rm -f "\(path)/setting-$3"; fi ;;
          'calendar events') cat '\(path)/events' ;;
          'reminders due') cat '\(path)/reminders' ;;
          'calendar calendars') cat '\(path)/calendars' ;;
          'reminders lists') cat '\(path)/lists' ;;
          'reminders add') if [ "$3" = --dry-run ]; then cat '\(path)/dry-reminder'; else cat '\(path)/added-reminder'; fi ;;
          'calendar add') if [ "$3" = --dry-run ]; then cat '\(path)/dry-event' 2>/dev/null || exit 1; else cat '\(path)/added-event'; fi ;;
        esac

        """.writeScript(to: folder.appendingPathComponent("tools/openspot"))
        let files = [
            "events": """
            row=event:A/1
            title=Holiday
            detail=All day · Home
            icon=calendar
            allday=true
            start=\(iso(-3600))
            end=\(iso(80_000))

            row=event:B/2
            title=Standup
            detail=Soon · Work
            icon=video
            color=#1BADF8
            start=\(iso(750))
            end=\(iso(1650))
            meeting=https://meet.google.com/abc-defg-hij

            row=event:C/3
            title=Design review
            detail=Later · Work
            icon=calendar
            start=\(iso(7200))
            end=\(iso(9000))

            """,
            "reminders": """
            row=reminder:R1
            title=Call mom
            detail=Late · Yesterday 18:00 · Family
            icon=circle
            tone=bad
            done=false

            row=reminder:R2
            title=Take pills
            detail=Done · Family
            icon=checkmark.circle.fill
            done=true

            row=reminder:R3
            title=Water the plants
            detail=18:00 · Family
            icon=circle
            done=false

            row=reminder:R4
            title=Pay rent
            detail=Tomorrow · Family
            icon=circle
            done=false

            """,
            "calendars": "row=A8E2\ntitle=Work\ndetail=iCloud\n\nrow=B1\ntitle=Home\ndetail=On My Mac\n\n",
            "lists": "row=7D10\ntitle=Family\ndetail=iCloud\n\n",
            "dry-reminder": "row=reminder:new\ntitle=Call Ana\ndetail=Tomorrow 09:00 · Family\n",
            "added-reminder": "row=reminder:R9\ntitle=Call Ana\ndetail=Tomorrow 09:00 · Family\n"
        ]
        for (name, text) in files {
            try text.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
    }

    @MainActor
    private static func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func calls(in folder: URL) throws -> [String] {
        try read("calls", in: folder).split(separator: "\n").map(String.init)
    }

    func testTheCardShowsTheNextTimedEventOverATickForEachOfTheFirstTwoOpenReminders() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let output = try await agenda.items(timeout: 5)

            let next = try XCTUnwrap(output.parts.first { $0.id == "next" })
            XCTAssertEqual(next.control, .metric("in 12 min"))
            XCTAssertEqual(next.title, "Standup")
            XCTAssertEqual(next.color, "#1BADF8")
            let ticks = output.parts.filter { $0.look == .tick }
            XCTAssertEqual(ticks.map(\.id), ["R1", "R3"])
            XCTAssertEqual(ticks.map(\.control), [.toggle(false), .toggle(false)])
            XCTAssertEqual(ticks.map(\.title), ["Call mom", "Water the plants"])
            XCTAssertEqual(ticks.map(\.detail), [nil, nil])
            XCTAssertEqual(output.parts.filter { $0.id.hasPrefix("due-") }.map(\.detail), ["Late", "18:00"])
            let time = DateFormatter()
            time.dateFormat = "HH:mm"
            XCTAssertEqual(output.parts.first { $0.id == "at" }?.control, .metric(time.string(from: Date().addingTimeInterval(750))))
            XCTAssertEqual(output.face.drawing(for: .large), [["next", "next", "next", "next"], ["next", "next", "next", "next"], ["R1", "R1", "R1", "due-R1"], ["R3", "R3", "R3", "due-R3"]])
            XCTAssertEqual(output.face.drawing(for: .square), [["next"], ["next"], ["R1"], ["R3"]])
            XCTAssertEqual(output.face.drawing(for: .strip), [["next"]])
            XCTAssertEqual(output.face.drawing(for: .wide), [["next"]])
            XCTAssertEqual(output.face.drawing(for: .small), [["at"]])
            XCTAssertEqual(output.errors, [])
            let calls = try self.calls(in: folder)
            XCTAssertEqual(calls.map { $0.split(separator: "|", omittingEmptySubsequences: false)[1] }, [
                "setting get calendars", "calendar events --days 2", "reminders due --days 2"
            ])
            XCTAssertTrue(calls.allSatisfy { $0.hasSuffix("|") }, "a call took stdin: \(calls)")
        }
    }

    func testTheRowsGiveEachReminderATickAndEachEventTheActionsThatFitIt() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let output = try await agenda.items(timeout: 5)
            let items = Dictionary(uniqueKeysWithValues: output.items.map { ($0.run, $0) })

            XCTAssertEqual(output.items.map(\.run), ["event:A/1", "event:B/2", "event:C/3", "reminder:R1", "reminder:R2", "reminder:R3", "reminder:R4"])
            XCTAssertEqual(items["event:B/2"]?.hides, ["tick"])
            XCTAssertEqual(items["event:C/3"]?.hides, ["tick", "join"])
            XCTAssertEqual(items["reminder:R1"]?.hides, ["join"])
            XCTAssertEqual(items["reminder:R1"]?.template, "reminder")
            let tick = try XCTUnwrap(output.template(of: try XCTUnwrap(items["reminder:R2"]))?.parts(of: try XCTUnwrap(items["reminder:R2"])).first)
            XCTAssertEqual(tick.look, .tick)
            XCTAssertEqual(tick.control, .toggle(true))
            XCTAssertEqual(tick.title, "Take pills")
            XCTAssertEqual(output.actions.map(\.id), ["join", "tick", "calendars"])
            XCTAssertEqual(output.primary, "Open")
        }
    }

    func testATypedTextOffersToAddItAndKeepsTheRowsThatMatch() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let reminderOnly = try await agenda.items(query: "call", timeout: 5)
            try "row=event:new\ntitle=Call Ana\ndetail=Tomorrow 09:00–10:00 · Work\n".write(to: folder.appendingPathComponent("dry-event"), atomically: true, encoding: .utf8)
            let both = try await agenda.items(query: "call", timeout: 5)

            XCTAssertEqual(reminderOnly.items.map(\.run), ["add-reminder", "reminder:R1"])
            XCTAssertEqual(reminderOnly.items.first?.title, "Add reminder")
            XCTAssertEqual(reminderOnly.items.first?.subtitle, "Call Ana · Tomorrow 09:00 · Family")
            XCTAssertEqual(both.items.map(\.run), ["add-reminder", "add-event", "reminder:R1"])
            XCTAssertEqual(both.items[1].subtitle, "Call Ana · Tomorrow 09:00–10:00 · Work")
            XCTAssertTrue(try self.calls(in: folder).contains { $0.hasSuffix("|reminders add --dry-run call|") })
        }
    }

    func testATypedTextFindsEachRowThatShowsItAndAnyFormOfIt() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let work = try await SpotRuns().answer(of: agenda, .items(query: "WORK"), limit: 5)
            let family = try await SpotRuns().answer(of: agenda, .items(query: "ауфьшдн", forms: ["family"]), limit: 5)

            XCTAssertEqual(PluginOutput(text: work).items.map(\.run), ["add-reminder", "event:B/2", "event:C/3"])
            XCTAssertEqual(PluginOutput(text: family).items.map(\.run), ["add-reminder", "reminder:R1", "reminder:R2", "reminder:R3", "reminder:R4"])
        }
    }

    func testTextTypedInTheOpenSheetShowsTheRowsThatMatch() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let rows = try await Self.rows(of: agenda, after: "call")

            XCTAssertEqual(rows, ["add-reminder", "reminder:R1"])
        }
    }

    /// The rows that the open sheet of a spot shows once the person types the text, through the app's own run of the spot.
    @MainActor
    private static func rows(of spot: Spot, after text: String) async throws -> [String] {
        let runs = SpotRuns()
        defer { runs.quit() }
        let sheet = runs.sheet(for: spot)
        sheet.open {}
        try await wait("the first rows") { !sheet.list.shown.isEmpty && !sheet.isReading }
        sheet.search(text)
        try await wait("the rows of the text") { sheet.list.shown.count < 7 }
        return sheet.list.shown.map(\.run)
    }

    func testPickingAnAddRowAddsTheTextOfTheFieldAndSaysSo() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let toast = try await agenda.perform(.item(SpotItem(title: "Add reminder", run: "add-reminder")), input: "search=Call Ana tomorrow 9am\n", timeout: 5)

            XCTAssertEqual(toast, "Added Call Ana.")
            XCTAssertTrue(try self.calls(in: folder).contains("act|reminders add Call Ana tomorrow 9am|"))
        }
    }

    func testATickInARowOrOnTheCardMarksTheReminderWhoseIdTheListPrinted() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            let output = try await agenda.items(timeout: 5)
            let row = try XCTUnwrap(output.items.first { $0.title == "Call mom" }?.run)
            let card = try XCTUnwrap(output.parts.first { $0.title == "Water the plants" }?.id)
            let done = try XCTUnwrap(output.items.first { $0.title == "Take pills" }?.run)

            try await agenda.perform(.slot("done", run: row, value: "true"), timeout: 5)
            try await agenda.perform(.set(card, to: "true"), timeout: 5)
            try await agenda.perform(.action(CommandAction(id: "tick", title: "Mark as done"), item: SpotItem(title: "Take pills", run: done)), timeout: 5)

            let marks = try self.calls(in: folder).filter { $0.contains("reminders done") }
            XCTAssertEqual(marks, ["act|reminders done reminder:R1 true|", "act|reminders done reminder:R3 true|", "act|reminders done reminder:R2 false|"])
        }
    }

    func testEnterOpensAnEventInCalendarAndAReminderInRemindersAndJoinOpensTheCall() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            try await agenda.perform(.item(SpotItem(title: "Standup", run: "event:B/2")), timeout: 5)
            try await agenda.perform(.item(SpotItem(title: "Call mom", run: "reminder:R1")), timeout: 5)
            try await agenda.perform(.action(CommandAction(id: "join", title: "Join call"), item: SpotItem(title: "Standup", run: "event:B/2")), timeout: 5)

            let opens = try self.calls(in: folder).filter { $0.contains(" show ") }
            XCTAssertEqual(opens, ["act|calendar show event:B/2|", "act|reminders show reminder:R1|"])
            XCTAssertEqual(try self.read("opened", in: folder), "https://meet.google.com/abc-defg-hij\n")
        }
    }

    func testWithNoLeaveTheSheetOffersToAskAndAPickAsksOutsideARead() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            for name in ["events", "reminders"] {
                try "status=unasked\n".write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
            }

            let output = try await agenda.items(timeout: 5)
            try await agenda.perform(.item(SpotItem(title: "Allow Calendar", run: "allow-calendar")), timeout: 5)

            XCTAssertEqual(output.items.map(\.run), ["allow-calendar", "allow-reminders"])
            XCTAssertEqual(output.parts.first { $0.id == "next" }?.control, .metric("Allow"))
            XCTAssertTrue(try self.calls(in: folder).contains("act|calendar events|"))
        }
    }

    func testAgendaHidesTheCalendarsAndListsOfItsCalendarsSetting() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            try "A8E2 7D10".write(to: folder.appendingPathComponent("setting-calendars"), atomically: true, encoding: .utf8)

            _ = try await agenda.items(timeout: 5)

            XCTAssertEqual(try self.calls(in: folder).map { $0.split(separator: "|", omittingEmptySubsequences: false)[1] }, [
                "setting get calendars", "calendar events --days 2 --hide A8E2 --hide 7D10", "reminders due --days 2 --hide A8E2 --hide 7D10"
            ])
        }
    }

    func testTheCalendarsSettingPicksEachShownCalendarAndListAndAPickHidesOrShowsOne() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            try "B1".write(to: folder.appendingPathComponent("setting-calendars"), atomically: true, encoding: .utf8)
            let calendars = SpotAction.action(CommandAction(id: "calendars", title: "Choose calendars"), item: nil)

            let first = try await SpotRuns().answer(of: agenda, calendars, limit: 5)
            let form = try XCTUnwrap(ItemForm(output: PluginOutput(text: first)))
            let choice = try XCTUnwrap(form.soleChoice)
            XCTAssertEqual(agenda.settings.map(\.id), ["calendars"])
            XCTAssertEqual(agenda.settings.first?.icon, "calendar")
            XCTAssertEqual(choice.options.map(\.id), ["A8E2", "B1", "7D10"])
            XCTAssertEqual(choice.options.map(\.title), ["Work · iCloud", "Home · On My Mac", "Family · iCloud"])
            XCTAssertEqual(choice.options.map(\.icon), ["calendar", "calendar", "list.bullet"])
            XCTAssertEqual(choice.picks, ["A8E2", "7D10"])

            let after = try await SpotRuns().answer(of: agenda, calendars, input: "calendars=7D10\n", limit: 5)
            XCTAssertEqual(try self.read("setting-calendars", in: folder), "B1 7D10")
            XCTAssertEqual(ItemForm(output: PluginOutput(text: after))?.soleChoice?.picks, ["A8E2"])
            _ = try await SpotRuns().answer(of: agenda, calendars, input: "calendars=B1\n", limit: 5)
            XCTAssertEqual(try self.read("setting-calendars", in: folder), "7D10")
            _ = try await SpotRuns().answer(of: agenda, calendars, input: "calendars=7D10\n", limit: 5)
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("setting-calendars").path))
        }
    }

    func testSelectAllInTheCalendarsSettingShowsEachCalendarAndList() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            try "B1 7D10".write(to: folder.appendingPathComponent("setting-calendars"), atomically: true, encoding: .utf8)
            let calendars = SpotAction.action(CommandAction(id: "calendars", title: "Choose calendars"), item: nil)
            let first = try await SpotRuns().answer(of: agenda, calendars, limit: 5)
            let form = try XCTUnwrap(ItemForm(output: PluginOutput(text: first)))
            let all = try XCTUnwrap(FormDraft(form: form).selectingAll())

            let after = try await SpotRuns().answer(of: agenda, calendars, input: all.text, limit: 5)

            XCTAssertEqual(all.values["calendars"], "B1\n7D10")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("setting-calendars").path))
            XCTAssertEqual(ItemForm(output: PluginOutput(text: after))?.soleChoice?.picks, ["A8E2", "B1", "7D10"])
        }
    }
}
