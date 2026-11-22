import XCTest
@testable import OpenspotCore

final class ViewVariantTests: XCTestCase {
    private let battery = """
    frame=
    class=p-3 card:p-0

    number=battery
    value=84
    max=100
    class=hidden card:flex

    text=note
    title=Charging
    class=card:hidden
    """

    func testAClassAppliesOnlyInItsPlaceItsSizeOrItsState() {
        let style = Style(classes: "p-3 card:p-0 wide:flex-row card:wide:gap-2 dark:hidden hover:opacity-50")

        XCTAssertEqual(style.resolved(for: [.sheet]).padding[.top], .steps(3))
        XCTAssertNil(style.resolved(for: [.sheet]).isHidden)
        XCTAssertEqual(style.resolved(for: [.card, .small]).padding[.top], .steps(0))
        XCTAssertNil(style.resolved(for: [.card, .small]).arrangement)
        XCTAssertEqual(style.resolved(for: [.card, .wide]).arrangement, .row)
        XCTAssertEqual(style.resolved(for: [.card, .wide]).columnGap, .steps(2))
        XCTAssertNil(style.resolved(for: [.wide]).columnGap)
        XCTAssertEqual(style.resolved(for: [.float, .dark]).isHidden, true)
        XCTAssertEqual(style.resolved(for: [.window, .hover]).opacity, 0.5)
    }

    func testAClassUnderMoreVariantsWinsOverOneUnderFewer() {
        let style = Style(classes: "card:hover:p-2 card:p-1 hover:p-3")

        XCTAssertEqual(style.resolved(for: [.card]).padding[.left], .steps(1))
        XCTAssertEqual(style.resolved(for: [.sheet, .hover]).padding[.left], .steps(3))
        XCTAssertEqual(style.resolved(for: [.card, .hover]).padding[.left], .steps(2))
    }

    func testAVariantKeepsTheClassesItDoesNotName() {
        let style = Style(classes: "hidden flex-row gap-part card:flex")

        let card = style.resolved(for: [.card, .large])
        XCTAssertEqual(card.isHidden, false)
        XCTAssertEqual(card.arrangement, .row)
        XCTAssertEqual(card.columnGap, .part)
        XCTAssertEqual(style.resolved(for: [.sheet]).isHidden, true)
    }

    func testATreeDrawsOnACardOnlyWhereItsClassesNameTheCardOrItsSize() {
        let card = Frame(text: battery).tree
        let wide = Frame(text: "frame=\nclass=wide:p-1\n\ntext=a\ntitle=A\n").tree
        let sheet = Frame(text: "frame=\nclass=p-1\n\ntext=a\ntitle=A\n").tree

        XCTAssertTrue(SpotSize.all.allSatisfy(card.draws(on:)))
        XCTAssertEqual(SpotSize.all.filter(wide.draws(on:)), [.wide])
        XCTAssertFalse(SpotSize.all.contains(where: sheet.draws(on:)))
        XCTAssertFalse(card.drawsOnBar)
        XCTAssertTrue(Frame(text: "frame=\nclass=bar:p-1\n\ntext=a\ntitle=A\n").tree.drawsOnBar)
    }

    func testTheNodesThatShowInAPlaceLeaveOutAHiddenNodeAndWhatItHolds() {
        let tree = Frame(text: """
        frame=
        class=gap-2

        box=head
        class=card:hidden

        text=name
        parent=head
        title=Home

        text=speed
        title=82
        class=hidden card:flex
        """).tree

        XCTAssertEqual(tree.shown(in: [.sheet]), ["head", "name"])
        XCTAssertEqual(tree.shown(in: [.card, .wide]), ["speed"])
        XCTAssertEqual(Frame(text: "frame=\nclass=bar:hidden\n\ntext=a\ntitle=A\n").tree.shown(in: [.bar]), [])
    }

    func testTheValueOfTheCardIsTheOneValueThatShowsOnTheCard() {
        let output = Frame(text: battery)

        XCTAssertEqual(output.value?.value("number"), "battery")
        XCTAssertEqual(output.metric?.value("value"), "84")
    }

    func testACardThatShowsOnlyOneSwitchIsThatSwitchAndShowsWhetherItIsOn() {
        let output = Frame(text: """
        frame=
        class=card:p-0

        text=label
        title=Lamp
        class=card:hidden

        switch=power
        value=true
        """)

        XCTAssertEqual(output.control?.id, "power")
        XCTAssertEqual(output.kind, .toggle)
        XCTAssertEqual(SpotState(output: output, header: SpotState(title: "Lamp")).on, true)
    }

    func testTheMenuBarShowsTheFirstValueThatShowsOnTheBar() {
        let output = Frame(text: """
        frame=
        class=gap-2

        text=time
        title=14:20
        class=hidden bar:flex

        text=date
        title=Sunday
        """)
        let sheetOnly = Frame(text: "frame=\nclass=p-1\n\ntext=time\ntitle=14:20\n")

        XCTAssertTrue(output.hasBar)
        XCTAssertEqual(MetricValue(output: output.barred)?.title, "14:20")
        XCTAssertFalse(sheetOnly.hasBar)
    }

    func testTheCardFaceHoldsTheTreeSoACardOfANamedSizeDrawsIt() {
        let face = Frame(text: battery).face

        XCTAssertTrue(face.tree.draws(on: .square))
        XCTAssertFalse(Frame(text: "frame=\ngrid.wide=a\n\ntext=a\ntitle=A\n").face.tree.draws(on: .wide))
    }
}
