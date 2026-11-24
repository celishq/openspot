import XCTest

final class DrawCallTests: XCTestCase {
    func testABlockIsACallWithItsNumberItsArgumentsAndWhatThePersonTyped() {
        let call = Call(lines: ["call=7", "arg=rename", #"input.item=2:Work/pl\\an"#, #"input.name=Two\nlines"#])

        XCTAssertEqual(call, .ask(id: 7, arguments: ["rename"], input: ["input.item": #"2:Work/pl\an"#, "input.name": "Two\nlines"]))
    }

    func testAStopBlockNamesTheCallToStop() {
        XCTAssertEqual(Call(lines: ["stop=3"]), .stop(3))
    }

    func testLinesWithNoCallAreNoCall() {
        XCTAssertNil(Call(lines: ["arg=show"]))
        XCTAssertNil(Call(lines: []))
    }

    func testAWrittenValueReadsBackTheSame() {
        for text in ["plain", "two\nlines", #"back\slash"#, #"\n as two signs"#, "ends with \\"] {
            XCTAssertEqual(Call.text(Call.written(text)), text)
        }
    }
}
