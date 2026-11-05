import XCTest
@testable import OpenspotCore

final class TranslationDraftTests: XCTestCase {
    private func draft() -> TranslationDraft {
        TranslationDraft(preferred: ["en-UA", "en", "ru", "uk"])
    }

    func testStartsOnAutomaticAndTranslatesIntoTheSecondLanguageOfThePerson() {
        let draft = draft()

        XCTAssertNil(draft.source)
        XCTAssertEqual(draft.target, "ru")
        XCTAssertFalse(draft.canSwap)
    }

    func testAPersonWithOneLanguageStillGetsATarget() {
        XCTAssertEqual(TranslationDraft(preferred: ["ru"]).target, "ru")
        XCTAssertEqual(TranslationDraft(preferred: []).target, "en")
    }

    func testKeepsTheLanguagesItWasGiven() {
        let draft = TranslationDraft(preferred: ["en"], source: "de", target: "fr")

        XCTAssertEqual(draft.source, "de")
        XCTAssertEqual(draft.target, "fr")
    }

    func testDetectedTextInTheTargetMovesTheTargetOn() {
        var draft = draft()

        draft.take(detected: "ru")

        XCTAssertEqual(draft.from, "ru")
        XCTAssertEqual(draft.target, "en")
        XCTAssertTrue(draft.needsTranslation)
    }

    func testAChosenSourceKeepsTheTargetWhateverIsDetected() {
        var draft = TranslationDraft(preferred: ["en", "ru"], source: "de", target: "ru")

        draft.take(detected: "ru")

        XCTAssertEqual(draft.target, "ru")
        XCTAssertEqual(draft.from, "de")
    }

    func testSwapTradesBothLanguagesAndBothTexts() {
        var draft = TranslationDraft(preferred: ["en", "ru"], source: "ru", target: "en")
        draft.input = "Привет"
        draft.take(output: "Hello")

        draft.swap()

        XCTAssertEqual(draft.source, "en")
        XCTAssertEqual(draft.target, "ru")
        XCTAssertEqual(draft.input, "Hello")
        XCTAssertEqual(draft.output, "Привет")
    }

    func testSwapOnAutomaticUsesTheDetectedLanguage() {
        var draft = draft()
        draft.take(detected: "en")

        draft.swap()

        XCTAssertEqual(draft.source, "ru")
        XCTAssertEqual(draft.target, "en")
        XCTAssertNil(draft.detected)
    }

    func testSwapDoesNothingBeforeALanguageIsKnown() {
        var draft = draft()
        draft.input = "?"

        draft.swap()

        XCTAssertNil(draft.source)
        XCTAssertEqual(draft.target, "ru")
        XCTAssertEqual(draft.input, "?")
    }

    func testSwapKeepsTextThatHasNoTranslationYet() {
        var draft = TranslationDraft(preferred: ["en", "ru"], source: "ru", target: "en")
        draft.input = "Привет"

        draft.swap()

        XCTAssertEqual(draft.input, "Привет")
        XCTAssertEqual(draft.output, "")
    }

    func testChoosingTheOtherSidesLanguageTradesThem() {
        var draft = TranslationDraft(preferred: ["en", "ru"], source: "en", target: "ru")

        draft.choose(target: "en")
        XCTAssertEqual(draft.source, "ru")
        XCTAssertEqual(draft.target, "en")

        draft.choose(source: "en")
        XCTAssertEqual(draft.source, "en")
        XCTAssertEqual(draft.target, "ru")
    }

    func testTwoFormsOfALanguageNeedNoTranslation() {
        var draft = TranslationDraft(preferred: ["en", "ru"], source: "en", target: "en-GB")

        XCTAssertFalse(draft.needsTranslation)

        draft.choose(target: "de")
        XCTAssertTrue(draft.needsTranslation)
    }

    func testTextWithOnlySpacesIsNoInput() {
        var draft = draft()
        draft.input = " \n "

        XCTAssertFalse(draft.hasInput)
    }
}
