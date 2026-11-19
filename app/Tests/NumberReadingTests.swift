@testable import OpenspotCore
import XCTest

final class NumberReadingTests: XCTestCase {
    private func part(_ text: String) throws -> SpotPart {
        try XCTUnwrap(Frame(text: text.placed).parts.first)
    }

    func testANumberWritesItsUnitAfterItsValueAndFillsToItsMax() throws {
        let battery = try part("number=battery\ntitle=Battery\nvalue=84\nmax=100\nunit=%\ndetail=3:12 left\n")

        XCTAssertEqual(battery.number?.text, "84%")
        XCTAssertEqual(battery.number?.fill, 0.84)
        XCTAssertEqual(battery.title, "Battery")
        XCTAssertEqual(battery.detail, "3:12 left")
    }

    func testAUnitThatTheShownTextHoldsIsNotWrittenTwice() throws {
        XCTAssertEqual(try part("number=price\nvalue=13.46\ndisplay=$13.46\nunit=$\n").number?.text, "$13.46")
        XCTAssertEqual(try part("number=weight\nvalue=12\nunit=kg\n").number?.text, "12 kg")
        XCTAssertEqual(try part("number=at\nvalue=14:30\n").number?.text, "14:30")
    }

    func testANumberWithNoMaxHasNoFill() throws {
        XCTAssertNil(try part("number=cups\nvalue=3\n").number?.fill)
    }

    func testEachValueLineIsAPointOfASeriesThatShowsItsLast() throws {
        let cpu = try XCTUnwrap(try part("number=cpu\nmax=100\nunit=%\nvalue=12\nvalue=18\nvalue=25\n").number)

        XCTAssertEqual(cpu.points, [12, 18, 25])
        XCTAssertTrue(cpu.isSeries)
        XCTAssertEqual(cpu.text, "25%")
        XCTAssertNil(cpu.fill)
        XCTAssertEqual(cpu.scaledPoints, [0.12, 0.18, 0.25])
    }

    func testAGraphIsNoKind() {
        XCTAssertTrue(Frame(text: "graph=disk\nvalue=0.5\n".placed).parts.isEmpty)
    }

    func testThePlaceOfANumberOnACardPicksItsLook() throws {
        let frame = Frame(text: """
        frame=
        grid.large=battery battery cpu cpu
        grid.large=battery battery memory memory
        grid.large=battery battery cups cups

        number=battery
        value=84
        max=100

        number=cpu
        max=100
        value=12
        value=25

        number=memory
        value=61
        max=100

        number=cups
        value=3

        """)
        let layout = try XCTUnwrap(frame.face.layout(for: .large))
        func look(_ id: String) throws -> NumberLook? {
            let index = try XCTUnwrap(layout.names.firstIndex(of: id))
            let cells = layout.cells(of: layout.slots[index], on: .large)
            return try XCTUnwrap(frame.face.parts.first { $0.id == id }).numberLook(columns: cells.columns, rows: cells.rows)
        }

        XCTAssertEqual(try look("battery"), .ring)
        XCTAssertEqual(try look("cpu"), .bar)
        XCTAssertEqual(try look("memory"), .bar)
        XCTAssertEqual(try look("cups"), .stat)
    }

    func testASeriesInATallPlaceIsAStatOverItsBars() throws {
        XCTAssertEqual(try part("number=cpu\nvalue=1\nvalue=2\n").numberLook(columns: 2, rows: 2), .stat)
        XCTAssertEqual(try part("number=cpu\nvalue=1\nvalue=2\n").numberLook(columns: 2, rows: 1), .bar)
    }

    func testAValueWithAMaxIsARingInASmallPlace() throws {
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\n").numberLook(columns: 1, rows: 1), .ring)
    }

    func testAValueWithAMaxIsABarAcrossAWideSheet() throws {
        let battery = try part("number=battery\nvalue=84\nmax=100\n")

        XCTAssertEqual(battery.numberLook(inSheetHeight: SpotTokens.listRow * 2), .bar)
        XCTAssertEqual(try part("number=cpu\nvalue=1\nvalue=2\n").numberLook(inSheetHeight: SpotTokens.listRow * 2), .stat)
    }

    func testALookTheSpotNamesWinsOverThePlace() throws {
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\nlook=bar\n").numberLook(columns: 2, rows: 2), .bar)
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\nlook=ring\n").numberLook(columns: 2, rows: 1), .ring)
    }

    func testANumberWithAMaxIsAGaugeInTheMenuBar() throws {
        let value = try XCTUnwrap(MetricValue(output: Frame(text: "number=battery\ntitle=Battery\nvalue=84\nmax=100\nunit=%\n")))

        XCTAssertEqual(value.kind, .gauge)
        XCTAssertEqual(value.title, "84%")
        XCTAssertEqual(value.fill, 0.84)
    }

    func testASeriesIsATrendInTheMenuBar() throws {
        let value = try XCTUnwrap(MetricValue(output: Frame(text: "number=cpu\nmax=100\nunit=%\nvalue=12\nvalue=25\n")))

        XCTAssertEqual(value.kind, .trend)
        XCTAssertEqual(value.title, "25%")
        XCTAssertEqual(value.scaledPoints, [0.12, 0.25])
    }
}
