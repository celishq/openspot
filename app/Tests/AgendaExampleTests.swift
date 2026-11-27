import XCTest
@testable import OpenspotCore

final class AgendaExampleTests: SampleSpotsCase {
    private let now = Date()

    private func iso(_ seconds: TimeInterval) -> String {
        let format = ISO8601DateFormatter()
        format.timeZone = .current
        return format.string(from: now.addingTimeInterval(seconds))
    }

    private func fakeOpenspot(in folder: URL) throws {
        let path = folder.path
        try """
        #!/bin/sh
        input=$(cat)
        printf 'act|%s|%s\\n' "$*" "$input" >> '\(path)/calls'
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
            item=event:A/1
            title=Holiday
            detail=All day · Home
            icon=calendar
            allday=true
            start=\(iso(-3600))
            end=\(iso(80_000))

            item=event:B/2
            title=Standup
            detail=Soon · Work
            icon=video
            color=#1BADF8
            start=\(iso(750))
            end=\(iso(1650))
            meeting=https://meet.google.com/abc-defg-hij

            item=event:C/3
            title=Design review
            detail=Later · Work
            icon=calendar
            start=\(iso(7200))
            end=\(iso(9000))

            """,
            "reminders": """
            item=reminder:R1
            title=Call mom
            detail=Late · Yesterday 18:00 · Family
            icon=circle
            tone=bad
            done=false

            item=reminder:R2
            title=Take pills
            detail=Done · Family
            icon=checkmark.circle.fill
            done=true

            item=reminder:R3
            title=Water the plants
            detail=18:00 · Family
            icon=circle
            done=false

            item=reminder:R4
            title=Pay rent
            detail=Tomorrow · Family
            icon=circle
            done=false

            """,
            "calendars": "item=A8E2\ntitle=Work\ndetail=iCloud\n\nitem=B1\ntitle=Home\ndetail=On My Mac\n\n",
            "lists": "item=7D10\ntitle=Family\ndetail=iCloud\n\n",
            "dry-reminder": "item=reminder:new\ntitle=Call Ana\ndetail=Tomorrow 09:00 · Family\n",
            "added-reminder": "item=reminder:R9\ntitle=Call Ana\ndetail=Tomorrow 09:00 · Family\n"
        ]
        for (name, text) in files {
            try text.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
    }

    @MainActor
    private static func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<6000 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func calls(in folder: URL) throws -> [String] {
        try read("calls", in: folder).split(separator: "\n").map(String.init)
    }

    func testTheCardShowsTheNextTimedEventOverTheRemindersThatEachSizeHasRoomFor() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let output = try await agenda.items(timeout: 30)

            let next = try XCTUnwrap(output.face.parts.first { $0.id == "next" })
            XCTAssertEqual(next.number?.text, "in 12 min")
            XCTAssertEqual(next.title, "Standup")
            XCTAssertEqual(next.color, "#1BADF8")
            let ticks = output.face.parts.filter(\.isTick)
            XCTAssertEqual(ticks.map(\.id), ["R1", "R3"])
            XCTAssertEqual(ticks.map(\.control), [.toggle(false), .toggle(false)])
            XCTAssertEqual(ticks.map(\.title), ["Call mom", "Water the plants"])
            XCTAssertEqual(ticks.map(\.detail), [nil, nil])
            XCTAssertEqual(output.face.parts.filter { $0.id.hasPrefix("due-") }.map(\.detail), ["Late", "18:00"])
            let time = DateFormatter()
            time.dateFormat = "HH:mm"
            XCTAssertEqual(output.face.parts.first { $0.id == "at" }?.number?.text, time.string(from: now.addingTimeInterval(750)))
            XCTAssertEqual(output.face.shown(in: Style.Variant.card(.large)), ["head", "next", "row-R1", "R1", "due-R1", "row-R3", "R3", "due-R3"])
            XCTAssertEqual(output.face.shown(in: Style.Variant.card(.square)), ["head", "next", "counts", "todo", "late"])
            XCTAssertEqual(output.face.parts.first { $0.id == "todo" }?.title, "3 to do")
            XCTAssertEqual(output.face.parts.first { $0.id == "late" }?.title, "1 late")
            XCTAssertEqual(output.face.parts.first { $0.id == "late" }?.tone, .bad)
            XCTAssertEqual(output.face.shown(in: Style.Variant.card(.strip)), ["head", "next"])
            XCTAssertEqual(output.face.shown(in: Style.Variant.card(.wide)), ["head", "next"])
            XCTAssertEqual(output.face.shown(in: Style.Variant.card(.small)), ["at"])
            XCTAssertEqual(output.errors, [])
            let calls = try self.calls(in: folder)
            XCTAssertEqual(calls.map { $0.split(separator: "|", omittingEmptySubsequences: false)[1] }, [
                "calendar events --days 2", "reminders due --days 2"
            ])
            XCTAssertTrue(calls.allSatisfy { $0.hasSuffix("|") }, "a call took stdin: \(calls)")
        }
    }

    func testTheStripCardOffersToJoinACallThatStartsWithinTenMinutes() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            let far = try await agenda.items(timeout: 30)
            let near = "item=event:B/2\ntitle=Standup\ndetail=Soon · Work\nicon=video\nstart=\(self.iso(300))\nend=\(self.iso(1200))\nmeeting=https://meet.google.com/abc-defg-hij\n"
            try near.write(to: folder.appendingPathComponent("events"), atomically: true, encoding: .utf8)

            let output = try await agenda.items(timeout: 30)
            try await agenda.perform("join-now", timeout: 30)

            XCTAssertEqual(far.face.shown(in: Style.Variant.card(.strip)), ["head", "next"])
            XCTAssertEqual(output.face.shown(in: Style.Variant.card(.strip)), ["head", "next", "join-now"])
            XCTAssertEqual(output.face.parts.first { $0.id == "join-now" }?.title, "Join")
            XCTAssertFalse(output.actions.contains { $0.id == "join-now" })
            XCTAssertEqual(try self.read("opened", in: folder), "https://meet.google.com/abc-defg-hij\n")
        }
    }

    func testTheRowsShowEachReminderAsItIsAndGiveEachRowTheActionsThatFitIt() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let output = try await agenda.items(timeout: 30)
            let items = Dictionary(uniqueKeysWithValues: output.items.map { ($0.run, $0) })

            XCTAssertEqual(output.items.map(\.run), ["event:A/1", "event:B/2", "event:C/3", "reminder:R1", "reminder:R2", "reminder:R3", "reminder:R4"])
            XCTAssertEqual(items["event:B/2"]?.hides, ["tick"])
            XCTAssertEqual(items["event:C/3"]?.hides, ["tick", "join"])
            XCTAssertEqual(items["reminder:R1"]?.hides, ["join"])
            XCTAssertEqual(items["reminder:R2"]?.symbol, "checkmark.circle.fill")
            XCTAssertEqual(items["reminder:R2"]?.title, "Take pills")
            XCTAssertEqual(output.errors, [])
            XCTAssertEqual(output.actions.map(\.id), ["join", "tick", "calendars"])
            XCTAssertEqual(output.openTitle, "Open")
        }
    }

    func testATypedTextOffersToAddItAndKeepsTheRowsThatMatch() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let reminderOnly = try await agenda.answer("sheet.text", input: "input.value=call\n", timeout: 30)
            try "item=event:new\ntitle=Call Ana\ndetail=Tomorrow 09:00–10:00 · Work\n".write(to: folder.appendingPathComponent("dry-event"), atomically: true, encoding: .utf8)
            let both = try await agenda.answer("sheet.text", input: "input.value=call\n", timeout: 30)

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

            let work = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: agenda, "sheet.text", input: "input.value=WORK\n", limit: 30)
            let family = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: agenda, "sheet.text", input: "input.value=ауфьшдн\ninput.alt=family\n", limit: 30)

            XCTAssertEqual(Frame(text: work).items.map(\.run), ["add-reminder", "event:B/2", "event:C/3"])
            XCTAssertEqual(Frame(text: family).items.map(\.run), ["add-reminder", "reminder:R1", "reminder:R2", "reminder:R3", "reminder:R4"])
        }
    }

    func testEachFormMatchesAsAWholeLine() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            let output = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: agenda, "sheet.text", input: "input.value=qqq\ninput.alt=mom call\ninput.alt=standup\n", limit: 30)

            XCTAssertEqual(Frame(text: output).items.map(\.run).filter { $0.contains(":") }, ["event:B/2"])
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

    @MainActor
    private static func rows(of spot: Spot, after text: String) async throws -> [String] {
        let runs = SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers)
        defer { runs.quit() }
        let sheet = runs.sheet(for: spot)
        sheet.open {}
        try await wait("the first rows") { !sheet.list.shown.isEmpty && !sheet.isShowing }
        sheet.search(text)
        try await wait("the answer to the text") { !sheet.list.isWaiting }
        return sheet.list.shown.map(\.run)
    }

    func testPickingAnAddRowAddsTheTextOfTheFieldAndSaysSo() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            try await agenda.perform("press", input: "input.item=add-reminder\ninput.item.words=Call Ana tomorrow 9am\n", timeout: 30)

            XCTAssertTrue(try self.calls(in: folder).contains("act|reminders add Call Ana tomorrow 9am|"))
            XCTAssertTrue(try self.calls(in: folder).contains("act|toast Added Call Ana.|"))
        }
    }

    func testTheTickActionOfARowOrATickOnTheCardMarksTheReminderWhoseIdTheListPrinted() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            let output = try await agenda.items(timeout: 30)
            let row = try XCTUnwrap(output.items.first { $0.title == "Call mom" }?.run)
            let card = try XCTUnwrap(output.face.parts.first { $0.title == "Water the plants" }?.id)
            let done = try XCTUnwrap(output.items.first { $0.title == "Take pills" }?.run)

            try await agenda.perform("tick", input: "input.item=\(row)\ninput.item.done=false\n", timeout: 30)
            try await agenda.perform(card, input: "input.value=true\n", timeout: 30)
            try await agenda.perform("tick", input: "input.item=\(done)\ninput.item.done=true\n", timeout: 30)

            let marks = try self.calls(in: folder).filter { $0.contains("reminders done") }
            XCTAssertEqual(try self.calls(in: folder).filter { $0.contains("reminders due") }.count, 1)
            XCTAssertEqual(marks, ["act|reminders done reminder:R1 true|", "act|reminders done reminder:R3 true|", "act|reminders done reminder:R2 false|"])
        }
    }

    func testEnterOpensAnEventInCalendarAndAReminderInRemindersAndJoinOpensTheCall() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)

            try await agenda.perform("press", input: "input.item=event:B/2\n", timeout: 30)
            try await agenda.perform("press", input: "input.item=reminder:R1\n", timeout: 30)
            try await agenda.perform("join", input: "input.item=event:B/2\ninput.item.meeting=https://meet.google.com/abc-defg-hij\n", timeout: 30)

            let opens = try self.calls(in: folder).filter { $0.contains(" show ") }
            XCTAssertEqual(opens, ["act|calendar show event:B/2|", "act|reminders show reminder:R1|"])
            XCTAssertEqual(try self.read("opened", in: folder), "https://meet.google.com/abc-defg-hij\n")
            XCTAssertFalse(try self.calls(in: folder).contains { $0.contains("calendar events") })
        }
    }

    func testWithNoLeaveTheSheetOffersToAskAndAPickAsksOutsideARead() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            for name in ["events", "reminders"] {
                try "status=unasked\n".write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
            }

            let output = try await agenda.items(timeout: 30)
            try await agenda.perform("press", input: "input.item=allow-calendar\n", timeout: 30)

            XCTAssertEqual(output.items.map(\.run), ["allow-calendar", "allow-reminders"])
            XCTAssertEqual(output.face.parts.first { $0.id == "next" }?.number?.text, "Allow")
            XCTAssertTrue(try self.calls(in: folder).contains("act|calendar events|"))
        }
    }

    func testAgendaHidesTheCalendarsAndListsOfItsCalendarsSetting() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            _ = try await agenda.items(input: "setting.calendars=A8E2 7D10\n", timeout: 30)

            XCTAssertEqual(try self.calls(in: folder).map { $0.split(separator: "|", omittingEmptySubsequences: false)[1] }, [
                "calendar events --days 2 --hide A8E2 --hide 7D10", "reminders due --days 2 --hide A8E2 --hide 7D10"
            ])
        }
    }

    func testTheCalendarsSettingPicksEachShownCalendarAndListAndAPickHidesOrShowsOne() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            try "B1".write(to: folder.appendingPathComponent("setting-calendars"), atomically: true, encoding: .utf8)
            let calendars = "calendars"

            let kept = { (try? self.read("setting-calendars", in: folder)).map { "setting.calendars=\($0)\n" } ?? "" }
            let first = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: agenda, calendars, input: kept(), limit: 30)
            let form = try XCTUnwrap(ItemForm(output: Frame(text: first)))
            let choice = try XCTUnwrap(form.soleChoice)
            XCTAssertEqual(agenda.settings.map(\.id), ["calendars"])
            XCTAssertEqual(agenda.settings.first?.icon, "calendar")
            XCTAssertEqual(choice.options.map(\.id), ["A8E2", "B1", "7D10"])
            XCTAssertEqual(choice.options.map(\.title), ["Work · iCloud", "Home · On My Mac", "Family · iCloud"])
            XCTAssertEqual(choice.options.map(\.icon), ["calendar", "calendar", "list.bullet"])
            XCTAssertEqual(choice.picks, ["A8E2", "7D10"])

            let after = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: agenda, calendars, input: "input.calendars=7D10\n" + kept(), limit: 30)
            XCTAssertEqual(try self.read("setting-calendars", in: folder), "B1 7D10")
            XCTAssertEqual(ItemForm(output: Frame(text: after))?.soleChoice?.picks, ["A8E2"])
            _ = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: agenda, calendars, input: "input.calendars=B1\n" + kept(), limit: 30)
            XCTAssertEqual(try self.read("setting-calendars", in: folder), "7D10")
            _ = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: agenda, calendars, input: "input.calendars=7D10\n" + kept(), limit: 30)
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("setting-calendars").path))
        }
    }

    func testSelectAllInTheCalendarsSettingShowsEachCalendarAndList() async throws {
        let agenda = try example("Agenda")
        try await withPrivateHome { folder in
            try self.fakeOpenspot(in: folder)
            try "B1 7D10".write(to: folder.appendingPathComponent("setting-calendars"), atomically: true, encoding: .utf8)
            let calendars = "calendars"
            let first = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: agenda, calendars, input: "setting.calendars=B1 7D10\n", limit: 30)
            let form = try XCTUnwrap(ItemForm(output: Frame(text: first)))
            let all = try XCTUnwrap(FormDraft(form: form).selectingAll())

            let after = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: agenda, calendars, input: (Message(calendars, inputs: all.inputs).text ?? "") + "setting.calendars=B1 7D10\n", limit: 30)

            XCTAssertEqual(all.values["calendars"], "B1\n7D10")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("setting-calendars").path))
            XCTAssertEqual(ItemForm(output: Frame(text: after))?.soleChoice?.picks, ["A8E2", "B1", "7D10"])
        }
    }
}
