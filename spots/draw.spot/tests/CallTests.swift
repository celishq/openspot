import XCTest

final class DrawCallTests: XCTestCase {
    func testABlockIsACallWithItsNumberItsArgumentsAndWhatThePersonTyped() {
        let call = Call(lines: ["call=7", "arg=rename", #"arg=2:Work/pl\\an"#, "env.OPENSPOT_PAGE=x", #"input=name=Two\\nlines\nsearch=pl\n"#])

        XCTAssertEqual(call, .ask(id: 7, arguments: ["rename", #"2:Work/pl\an"#], input: ["name": "Two\nlines", "search": "pl"]))
    }

    func testAStopBlockNamesTheCallToStop() {
        XCTAssertEqual(Call(lines: ["stop=3"]), .stop(3))
    }

    func testLinesWithNoCallAreNoCall() {
        XCTAssertNil(Call(lines: ["arg=read"]))
        XCTAssertNil(Call(lines: []))
    }

    func testAWrittenValueReadsBackTheSame() {
        for text in ["plain", "two\nlines", #"back\slash"#, #"\n as two signs"#, "ends with \\"] {
            XCTAssertEqual(Call.text(Call.written(text)), text)
        }
    }
}
