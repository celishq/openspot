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

    func testASeriesInATallPlaceIsAStatOverItsBars() throws {
        XCTAssertEqual(try part("number=cpu\nvalue=1\nvalue=2\n").numberLook(columns: 2, rows: 2), .stat)
        XCTAssertEqual(try part("number=cpu\nvalue=1\nvalue=2\n").numberLook(columns: 2, rows: 1), .bar)
    }

    func testASeriesWithNoMaxIsABarInAPlaceOfOneColumn() throws {
        XCTAssertEqual(try part("number=cpu\nvalue=1\nvalue=2\n").numberLook(columns: 1, rows: 2), .bar)
    }

    func testANumberRowSendsNoKeyOfTheBlockAsItsOwn() {
        let plain = Frame(text: "number=a\nvalue=1\nmax=5\nunit=%\ndisplay=1 of 5\n").items.first
        let own = Frame(text: "number=a\nvalue=1\nmax=5\nmeeting=42\n").items.first

        XCTAssertEqual(plain?.fields, [])
        XCTAssertEqual(own?.fields.first { $0.key == "meeting" }?.value, "42")
    }

    func testASeriesWithAMaxIsARingOfItsLastValueInANarrowPlace() throws {
        let cpu = try part("number=cpu\nmax=100\nvalue=10\nvalue=40\n")

        XCTAssertEqual(cpu.numberLook(columns: 0.9, rows: 1.4), .ring)
        XCTAssertEqual(cpu.numberLook(columns: 2, rows: 2), .stat)
    }

    func testAValueWithAMaxIsARingInASmallPlace() throws {
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\n").numberLook(columns: 1, rows: 1), .ring)
    }

    func testASheetTileOfTwoLinesDrawsABarAndATallPlaceAStat() throws {
        let battery = try part("number=battery\nvalue=84\nmax=100\n")

        let tile = CGSize(width: SpotTokens.partsWidth / 2, height: SpotTokens.listRow * 2 + SpotTokens.partGap)
        let series = try part("number=cpu\nvalue=1\nvalue=2\n")

        XCTAssertEqual(battery.numberLook(inSheet: tile), .bar)
        XCTAssertEqual(series.numberLook(inSheet: tile), .bar)
        XCTAssertEqual(series.numberLook(inSheet: CGSize(width: SpotTokens.partsWidth, height: SpotTokens.cell * 2)), .stat)
    }

    func testAChartTheSpotNamesWinsOverThePlace() throws {
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\nchart=bar\n").numberLook(columns: 2, rows: 2), .bar)
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\nchart=ring\n").numberLook(columns: 2, rows: 1), .ring)
    }

    func testALookOfRingOrBarIsAnUnknownKeyAndDrawsByThePlace() throws {
        let block = try XCTUnwrap(TextBlock.blocks(in: "number=battery\nvalue=84\nmax=100\nlook=bar\n").first)

        XCTAssertEqual(BlockKind.faults(in: block), ["the part battery has an unknown key: look"])
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\nlook=bar\n").numberLook(columns: 1, rows: 1), .ring)
    }

    func testAChartIsAKeyOfANumberOnly() throws {
        let text = try XCTUnwrap(TextBlock.blocks(in: "text=t\ntitle=T\nchart=ring\n").first)
        let number = try XCTUnwrap(TextBlock.blocks(in: "number=n\nvalue=1\nchart=pie\n").first)

        XCTAssertEqual(BlockKind.faults(in: text), ["the part t has an unknown key: chart"])
        XCTAssertEqual(BlockKind.faults(in: number), ["the part n has an unknown chart: pie"])
    }

    func testANumberPrintedAsARowShowsItsValueOrItsRingOnTheRight() throws {
        let frame = Frame(text: "frame=\nclass=gap-part\n\nnumber=cpu\nvalue=10\nmax=100\n\nitems=list\n\nnumber=cpu-1\nparent=list\ntitle=WindowServer\nvalue=32.7\nunit=%\n\nnumber=device-1\nparent=list\ntitle=AirPods\nvalue=74\nmax=100\nunit=%\n")

        XCTAssertEqual(frame.items.map(\.run), ["cpu-1", "device-1"])
        XCTAssertEqual(frame.items.first?.number?.text, "32.7%")
        XCTAssertNil(frame.items.first?.number?.fill)
        XCTAssertEqual(frame.items.last?.number?.fill, 0.74)
        XCTAssertEqual(frame.items.last?.number?.bare, "74")
    }

    func testANumberWithAMaxIsAGaugeInTheMenuBar() throws {
        let value = try XCTUnwrap(MetricValue(output: Frame(text: "number=battery\ntitle=Battery\nvalue=84\nmax=100\nunit=%\n")))

        XCTAssertEqual(value.kind, .gauge)
        XCTAssertEqual(value.title, "84%")
        XCTAssertEqual(value.number?.fill, 0.84)
    }

    func testASeriesIsATrendInTheMenuBar() throws {
        let value = try XCTUnwrap(MetricValue(output: Frame(text: "number=cpu\nmax=100\nunit=%\nvalue=12\nvalue=25\n")))

        XCTAssertEqual(value.kind, .trend)
        XCTAssertEqual(value.title, "25%")
        XCTAssertEqual(value.number?.scaledPoints, [0.12, 0.25])
    }
}
