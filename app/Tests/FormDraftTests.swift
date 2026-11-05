import XCTest
@testable import OpenspotCore

final class FormDraftTests: XCTestCase {
    private let form = ItemForm(title: "New", fields: [
        .init(name: "title", label: "Name", required: true),
        .init(name: "content", label: "Content", type: .multiline, value: "old")
    ])

    func testDecodesAForm() throws {
        let json = #"{"title":"New","fields":[{"name":"title","label":"Name","type":"text","required":true},{"name":"content","label":"Content","type":"multiline","value":"old"}]}"#

        XCTAssertEqual(try JSONDecoder().decode(ItemForm.self, from: Data(json.utf8)), form)
    }

    func testStartsFromTheFormsValues() {
        XCTAssertEqual(FormDraft(form: form).values, ["title": "", "content": "old"])
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

    func testTheJsonKeepsQuotesAndNewLines() throws {
        var draft = FormDraft(form: form)
        draft.set("say \"hi\"\nthen go", for: "content")

        let values = try JSONDecoder().decode([String: String].self, from: Data(draft.json.utf8))

        XCTAssertEqual(values["content"], "say \"hi\"\nthen go")
    }
}
