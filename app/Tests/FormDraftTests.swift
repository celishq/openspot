import XCTest
@testable import OpenspotCore

final class FormDraftTests: XCTestCase {
    private let form = ItemForm(title: "New", fields: [
        .init(name: "title", label: "Name", required: true),
        .init(name: "content", label: "Content", type: .multiline, value: "old")
    ])

    func testStartsFromTheFormsValues() {
        XCTAssertEqual(FormDraft(form: form).values, ["title": "", "content": "old"])
    }

    func testAFormTakesAChoiceASwitchAndASliderWithTheirValues() throws {
        let form = try XCTUnwrap(ItemForm(output: PluginOutput(text: """
        title=Repos

        choice=editor
        title=Editor
        option=/Applications/Zed.app:Zed
        option=/System/Library/CoreServices/Finder.app:Finder

        switch=hidden
        title=Show hidden folders
        on=true

        slider=depth
        title=Depth
        level=2
        min=1
        max=4

        field=note
        title=Note
        type=choice
        """)))

        XCTAssertEqual(form.fields.map(\.type), [.choice, .switch, .slider, .text])
        XCTAssertEqual(form.fields[0].options.map(\.title), ["Zed", "Finder"])
        XCTAssertEqual(form.fields[2].range, 1...4)
        XCTAssertEqual(FormDraft(form: form).values, ["editor": "/Applications/Zed.app", "hidden": "true", "depth": "2", "note": ""])
    }

    func testAFormOfOneChoiceListsItsOptionsAsRowsThatTheArrowsChoose() throws {
        let form = try XCTUnwrap(ItemForm(output: PluginOutput(text: "title=Editor\n\nchoice=editor\ntitle=Editor\nvalue=b\noption=a:A\noption=b:B\noption=c:C\n")))
        var draft = FormDraft(form: form)

        XCTAssertEqual(draft.choices?.shown.map(\.title), ["A", "B", "C"])
        XCTAssertEqual(draft.choices?.selectedItem?.run, "b")
        draft.move(by: 1)
        XCTAssertEqual(draft.values["editor"], "c")
        draft.move(by: 3)
        XCTAssertEqual(draft.values["editor"], "c")
        draft.choose("a")
        XCTAssertEqual(draft.values["editor"], "a")
        XCTAssertEqual(draft.choices?.selectedItem?.run, "a")
        let longer = try XCTUnwrap(ItemForm(output: PluginOutput(text: "title=Editor\n\nchoice=editor\ntitle=Editor\noption=a\noption=b\noption=c\noption=d\n")))
        XCTAssertLessThan(SpotTokens.formRect(form).height, SpotTokens.formRect(longer).height)
    }

    func testAChoiceOfSeveralMarksEachPickAndSendsTheOptionThatAPressTurnsOrEachOneThatSelectAllTurnsOn() throws {
        let form = try XCTUnwrap(ItemForm(output: PluginOutput(text: """
        title=Calendars

        choice=shown
        title=Calendars
        type=multiple
        option=a:Work · iCloud:calendar
        option=b:Home
        option=c:Family · iCloud:list.bullet
        value=a
        value=c
        """)))
        var draft = FormDraft(form: form)

        XCTAssertEqual(form.soleChoice?.picks, ["a", "c"])
        XCTAssertEqual(draft.choices?.shown.map(\.title), ["Work · iCloud", "Home", "Family · iCloud"])
        XCTAssertEqual(draft.choices?.shown.map(\.isOn), [true, false, true])
        XCTAssertEqual(draft.choices?.shown.map(\.symbol), ["calendar", nil, "list.bullet"])
        XCTAssertEqual(draft.choices?.selectedItem?.run, "a")
        draft.move(by: 1)
        XCTAssertEqual(draft.values["shown"], "b")
        XCTAssertEqual(draft.selectingAll()?.values["shown"], "b")
        XCTAssertEqual(draft.values["shown"], "b")
        let kept = FormDraft(form: form, after: draft)
        XCTAssertEqual(kept.choices?.selectedItem?.run, "b")
        XCTAssertEqual(kept.values["shown"], "b")
        let all = try XCTUnwrap(ItemForm(output: PluginOutput(text: "title=A\n\nchoice=shown\ntitle=A\ntype=multiple\noption=a\noption=b\nvalue=a\nvalue=b\n")))
        XCTAssertNil(FormDraft(form: all).selectingAll())
        let none = try XCTUnwrap(ItemForm(output: PluginOutput(text: "title=A\n\nchoice=shown\ntitle=A\ntype=multiple\noption=a\noption=b\n")))
        XCTAssertEqual(FormDraft(form: none).selectingAll()?.values["shown"], "a\nb")
        XCTAssertNil(FormDraft(form: try XCTUnwrap(ItemForm(output: PluginOutput(text: "title=A\n\nchoice=one\ntitle=A\noption=a\noption=b\n")))).selectingAll())
    }

    func testAnOptionKeepsEachColonOfItsTitleBeforeItsIcon() throws {
        let form = try XCTUnwrap(ItemForm(output: PluginOutput(text: "title=A\n\nchoice=c\ntitle=A\noption=a:Team: Design:calendar\noption=b:B\noption=c\n")))

        XCTAssertEqual(form.fields[0].options, [.init(id: "a", title: "Team: Design", icon: "calendar"), .init(id: "b", title: "B"), .init(id: "c", title: "c")])
    }

    func testAFormWithAChoiceAndAFieldKeepsItsControls() throws {
        let form = try XCTUnwrap(ItemForm(output: PluginOutput(text: "title=Editor\n\nchoice=editor\ntitle=Editor\noption=a:A\n\nfield=note\ntitle=Note\n")))

        XCTAssertNil(FormDraft(form: form).choices)
    }

    func testAPrefillGoesIntoAnEmptyFirstField() {
        XCTAssertEqual(FormDraft(form: form, prefill: "typed").values["title"], "typed")
    }

    func testAPrefillDoesNotReplaceAValue() {
        let edit = ItemForm(title: "Edit", fields: [.init(name: "title", label: "Name", value: "kept")])

        XCTAssertEqual(FormDraft(form: edit, prefill: "typed").values["title"], "kept")
    }

    func testFindsARequiredFieldWithOnlySpaces() {
        var draft = FormDraft(form: form)
        draft.set("  \n", for: "title")
        XCTAssertEqual(draft.missing?.name, "title")

        draft.set("Name", for: "title")
        XCTAssertNil(draft.missing)
    }
}
