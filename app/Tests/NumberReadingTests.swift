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

    func testASeriesHoldsItsPointsOnOneLineAndShowsItsLast() throws {
        let cpu = try XCTUnwrap(try part("series=cpu\nmax=100\nunit=%\nvalue=12,18,25\n").number)

        XCTAssertEqual(cpu.points, [12, 18, 25])
        XCTAssertTrue(cpu.isSeries)
        XCTAssertEqual(cpu.text, "25%")
        XCTAssertNil(cpu.fill)
        XCTAssertEqual(cpu.scaledPoints, [0.12, 0.18, 0.25])
        XCTAssertEqual(cpu.look, .stat)
    }

    func testADashInASeriesIsAGap() throws {
        XCTAssertEqual(try part("series=cpu\nvalue=2, -, 4\n").number?.scaledPoints, [0.5, nil, 1])
    }

    func testAGraphIsNoKind() {
        XCTAssertTrue(Frame(text: "graph=disk\nvalue=0.5\n".placed).parts.isEmpty)
    }

    func testANumberRowSendsNoKeyOfTheBlockAsItsOwn() {
        let plain = Frame(text: "number=a\nvalue=1\nmax=5\nunit=%\ndisplay=1 of 5\n").items.first
        let own = Frame(text: "number=a\nvalue=1\nmax=5\nmeeting=42\n").items.first

        XCTAssertEqual(plain?.fields, [])
        XCTAssertEqual(own?.fields.first { $0.key == "meeting" }?.value, "42")
    }

    func testANumberIsPlainTextUnlessItsTypeAsksForARingOrABar() throws {
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\n").number?.look, .stat)
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\ntype=ring\n").number?.look, .ring)
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\ntype=bar\n").number?.look, .bar)
    }

    func testARingOrABarWithNoMaxAndAnUnknownTypeAreFaults() throws {
        func faults(_ text: String) throws -> [String] { BlockKind.faults(in: try XCTUnwrap(TextBlock.blocks(in: text).first)) }

        XCTAssertEqual(try faults("number=n\nvalue=1\ntype=ring\n"), ["the number n has type=ring, which needs a max"])
        XCTAssertEqual(try faults("number=n\nvalue=1\nmax=2\ntype=bar\n"), [])
        XCTAssertEqual(try faults("number=n\nvalue=1\ntype=pie\n"), ["the part n has an unknown type: pie. Use ring or bar"])
        XCTAssertEqual(try faults("series=s\nvalue=1,2\ntype=ring\n"), ["the part s has an unknown type: ring"])
    }

    func testASecondValueOfANumberAndASecondValueLineOfASeriesAreFaults() throws {
        func faults(_ text: String) throws -> [String] { BlockKind.faults(in: try XCTUnwrap(TextBlock.blocks(in: text).first)) }

        XCTAssertEqual(try faults("number=n\nvalue=1\nvalue=2\n"), ["the number n has more than one value. Print points over time as a series, with value=1,2,3"])
        XCTAssertEqual(try faults("series=s\nvalue=1\nvalue=2\n"), ["the series s has more than one value line. Print its points on one line, as value=1,2,3"])
    }

    func testAChartAndALookAreUnknownKeys() throws {
        let chart = try XCTUnwrap(TextBlock.blocks(in: "number=n\nvalue=1\nmax=2\nchart=ring\n").first)
        let look = try XCTUnwrap(TextBlock.blocks(in: "number=battery\nvalue=84\nmax=100\nlook=bar\n").first)

        XCTAssertEqual(BlockKind.faults(in: chart), ["the part n has an unknown key: chart"])
        XCTAssertEqual(BlockKind.faults(in: look), ["the part battery has an unknown key: look"])
        XCTAssertEqual(try part("number=battery\nvalue=84\nmax=100\nlook=bar\n").number?.look, .stat)
    }

    func testAddAppendsPointsAfterTheValueAndKeepDropsTheOldest() throws {
        XCTAssertEqual(try part("series=s\nvalue=1,2\nadd=3,4\nkeep=3\n").number?.points, [2, 3, 4])
        XCTAssertEqual(try part("series=s\nadd=5\n").number?.points, [5])
    }

    func testASeriesKeepsSixtyPointsByDefaultAndSixHundredAtMost() throws {
        let many = (1...700).map(String.init).joined(separator: ",")

        XCTAssertEqual(try part("series=s\nvalue=\(many)\n").number?.points.count, 60)
        XCTAssertEqual(try part("series=s\nvalue=\(many)\nkeep=1000\n").number?.points.count, 600)
        XCTAssertEqual(try part("series=s\nvalue=\(many)\nkeep=1000\n").number?.points.last, 700)
    }

    func testALaterBlockAddsPointsAndAValueReplacesThemFirst() throws {
        let added = try part("series=s\nvalue=1,2\n\nseries=s\nadd=3\n\nseries=s\nadd=4,5\nkeep=4\n")
        let replaced = try part("series=s\nvalue=1,2\nadd=3\n\nseries=s\nvalue=9\nadd=10\n")
        let kept = try part("series=s\nvalue=1,2\nadd=3\n\nseries=s\ntitle=T\n")

        XCTAssertEqual(added.number?.points, [2, 3, 4, 5])
        XCTAssertEqual(replaced.number?.points, [9, 10])
        XCTAssertEqual(kept.number?.points, [1, 2, 3])
    }

    func testANumberPrintedAsARowShowsItsValueOrItsRingOnTheRight() throws {
        let frame = Frame(text: "frame=\nclass=gap-part\n\nnumber=cpu\nvalue=10\nmax=100\n\nitems=list\n\nnumber=cpu-1\nparent=list\ntitle=WindowServer\nvalue=32.7\nunit=%\n\nnumber=device-1\nparent=list\ntitle=AirPods\nvalue=74\nmax=100\nunit=%\ntype=ring\n")

        XCTAssertEqual(frame.items.map(\.run), ["cpu-1", "device-1"])
        XCTAssertEqual(frame.items.first?.number?.text, "32.7%")
        XCTAssertNil(frame.items.first?.number?.fill)
        XCTAssertEqual(frame.items.last?.number?.fill, 0.74)
        XCTAssertEqual(frame.items.last?.number?.bare, "74")
        XCTAssertEqual(frame.items.map { $0.number?.look }, [.stat, .ring])
    }

    func testARingOrABarIsAGaugeInTheMenuBarAndAPlainNumberIsItsText() throws {
        let value = try XCTUnwrap(MetricValue(output: Frame(text: "number=battery\ntitle=Battery\nvalue=84\nmax=100\nunit=%\ntype=ring\n")))
        let bar = try XCTUnwrap(MetricValue(output: Frame(text: "number=battery\ntitle=Battery\nvalue=84\nmax=100\nunit=%\ntype=bar\n")))
        let plain = try XCTUnwrap(MetricValue(output: Frame(text: "number=battery\ntitle=Battery\nvalue=84\nmax=100\nunit=%\n")))

        XCTAssertEqual(bar.kind, .gauge)
        XCTAssertEqual(plain.kind, .value)

        XCTAssertEqual(value.kind, .gauge)
        XCTAssertEqual(value.title, "84%")
        XCTAssertEqual(value.number?.fill, 0.84)
    }

    func testASeriesIsATrendInTheMenuBar() throws {
        let value = try XCTUnwrap(MetricValue(output: Frame(text: "series=cpu\nmax=100\nunit=%\nvalue=12,25\n")))

        XCTAssertEqual(value.kind, .trend)
        XCTAssertEqual(value.title, "25%")
        XCTAssertEqual(value.number?.scaledPoints, [0.12, 0.25])
    }
}
