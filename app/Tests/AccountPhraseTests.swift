import XCTest
@testable import OpenspotCore

final class AccountPhraseTests: XCTestCase {
    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    func testAPastedPhraseNumbersItsWordsAndNamesTheAccountItOpens() throws {
        let typed = AccountPhrase(" \(phrase.uppercased())\n")

        XCTAssertEqual(typed.typed.map(\.text), phrase.split(separator: " ").map(String.init))
        XCTAssertTrue(typed.typed.allSatisfy(\.isKnown))
        XCTAssertEqual(typed.counter, "12 of 12")
        XCTAssertEqual(typed.account, try AccountKey(words: phrase.split(separator: " ").map(String.init)).npub)
        XCTAssertTrue(typed.canSignIn)
    }

    func testAWordOutOfTheListIsMarkedAtOnceButTheOneBeingTypedIsNot() {
        XCTAssertEqual(AccountPhrase("abandon abuot aba").typed.map(\.isKnown), [true, false, true])
        XCTAssertEqual(AccountPhrase("abandon abandon zzz").typed.last?.isKnown, false)
        XCTAssertNil(AccountPhrase("abandon abuot aba").problem)
        XCTAssertFalse(AccountPhrase("abandon abuot aba").canSignIn)
    }

    func testTheWordBeingTypedHasACompletion() {
        XCTAssertEqual(AccountPhrase("abandon abso").completion, "absorb")
        XCTAssertNil(AccountPhrase("abandon absorb ").completion)
    }

    func testTwelveWordsThatAreNoAccountSayToCheckTheOrder() {
        let typed = AccountPhrase(Array(repeating: "abandon", count: 12).joined(separator: " "))

        XCTAssertEqual(typed.problem, "These words don't match an account. Check each word and their order.")
        XCTAssertNil(typed.account)
    }

    func testMoreThanTwelveWordsSayHowMany() {
        let typed = AccountPhrase(phrase + " abandon")

        XCTAssertEqual(typed.counter, "13 of 12")
        XCTAssertEqual(typed.problem, "An account has 12 words, and this has 13.")
    }

    func testAnNsecOpensItsAccount() throws {
        let key = try AccountKey.make()

        XCTAssertEqual(AccountPhrase(key.nsec).account, key.npub)
        XCTAssertNil(AccountPhrase("nsec1abc").problem)
        XCTAssertEqual(AccountPhrase("nsec1" + String(repeating: "q", count: 58)).problem, "This is not an nsec.")
    }

    func testTheFactsSayHowFarThePhraseIs() {
        XCTAssertEqual(AccountPhrase("abandon abuot abso").facts, "counter=3 of 12\nword=abandon\nword=abuot\nword=abso\nunknown=2\ncompletion=absorb\n")
    }

    func testABoxSuggestsTheWordsThatStartWithItsLetters() {
        XCTAssertEqual(AccountPhrase.suggestions(for: "abs"), ["absent", "absorb", "abstract", "absurd"])
        XCTAssertEqual(AccountPhrase.suggestions(for: ""), [])
    }
}
