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
