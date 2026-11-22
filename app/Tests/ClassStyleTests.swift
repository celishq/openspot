import XCTest
@testable import OpenspotCore

final class ClassStyleTests: XCTestCase {
    func testLayoutClassesChooseHowABoxPlacesItsChildren() {
        XCTAssertNil(Style(classes: "").arrangement)
        XCTAssertEqual(Style(classes: "flex-row").arrangement, .row)
        XCTAssertEqual(Style(classes: "flex-col").arrangement, .column)
        XCTAssertEqual(Style(classes: "relative").arrangement, .layers)
        XCTAssertEqual(Style(classes: "flex-row flex-col").arrangement, .column)

        let grid = Style(classes: "grid grid-cols-3 col-span-2 row-span-6")
        XCTAssertEqual(grid.arrangement, .grid)
        XCTAssertEqual(grid.columns, 3)
        XCTAssertEqual(grid.columnSpan, 2)
        XCTAssertEqual(grid.rowSpan, 6)

        let layer = Style(classes: "absolute inset-0")
        XCTAssertTrue(layer.isAbsolute)
        XCTAssertEqual(layer.pins, [.top, .right, .bottom, .left])
        XCTAssertEqual(Style(classes: "top-0 left-0").pins, [.top, .left])

        XCTAssertEqual(Style(classes: "hidden").isHidden, true)
        XCTAssertEqual(Style(classes: "hidden flex").isHidden, false)
    }

    func testAlignmentClassesPlaceTheChildrenOnBothAxes() {
        let style = Style(classes: "items-center justify-between self-end")
        XCTAssertEqual(style.items, .center)
        XCTAssertEqual(style.justify, .between)
        XCTAssertEqual(style.alignSelf, .end)
        XCTAssertEqual(Style(classes: "items-stretch justify-start self-start").items, .stretch)
    }

    func testASpaceStepIsTheSpacingUnitTimesTheStep() {
        let style = Style(classes: "p-3 px-0.5 pt-96 gap-x-2 gap-y-12")
        XCTAssertEqual(style.padding[.top], .steps(96))
        XCTAssertEqual(style.padding[.bottom], .steps(3))
        XCTAssertEqual(style.padding[.left], .steps(0.5))
        XCTAssertEqual(style.padding[.right], .steps(0.5))
        XCTAssertEqual(style.columnGap, .steps(2))
        XCTAssertEqual(style.rowGap, .steps(12))
        XCTAssertEqual(SpotTokens.spaceUnit, 4)
        XCTAssertEqual(Style.Length.steps(3).points(of: 100), 12)
        XCTAssertEqual(Style(classes: "gap-3").columnGap, .steps(3))
        XCTAssertEqual(Style(classes: "gap-3").rowGap, .steps(3))
    }

    func testAMeasuredSpaceKeepsItsOwnValue() {
        let style = Style(classes: "gap-part py-group")
        XCTAssertEqual(style.columnGap?.points(of: 0), SpotTokens.partGap)
        XCTAssertEqual(style.rowGap?.points(of: 0), 6)
        XCTAssertEqual(style.padding[.top]?.points(of: 0), SpotTokens.partGroupGap)
        XCTAssertEqual(style.padding[.bottom]?.points(of: 0), 24)
        XCTAssertNil(style.padding[.left])
    }

    func testSizeClassesTakeTheScaleTheWholeAndAShare() {
        let style = Style(classes: "w-1/3 h-full min-w-4 max-w-96 grow shrink-0 aspect-square")
        XCTAssertEqual(style.width?.points(of: 300), 100)
        XCTAssertEqual(style.height, .full)
        XCTAssertEqual(style.minWidth, .steps(4))
        XCTAssertEqual(style.maxWidth, .steps(96))
        XCTAssertEqual(style.grows, true)
        XCTAssertEqual(style.shrinks, false)
        XCTAssertTrue(style.isSquare)

        let square = Style(classes: "size-8 w-full")
        XCTAssertEqual(square.width, .full)
        XCTAssertEqual(square.height, .steps(8))
    }

    func testWordColourAndShapeClassesNameTheLooksOfTheTheme() {
        let words = Style(classes: "font-section font-semibold text-right truncate line-clamp-2 tabular-nums")
        XCTAssertEqual(words.font, .section)
        XCTAssertEqual(words.weight, .semibold)
        XCTAssertEqual(words.textAlignment, .right)
        XCTAssertTrue(words.truncates)
        XCTAssertEqual(words.lineLimit, 2)
        XCTAssertTrue(words.tabularNumbers)

        let colour = Style(classes: "text-secondary bg-tile backdrop-blur opacity-45")
        XCTAssertEqual(colour.ink, .secondary)
        XCTAssertEqual(colour.fill, .tile)
        XCTAssertTrue(colour.blursBackdrop)
        XCTAssertEqual(colour.opacity, 0.45)

        let shape = Style(classes: "rounded-inner border overflow-hidden")
        XCTAssertEqual(shape.corner, .inner)
        XCTAssertTrue(shape.hasBorder)
        XCTAssertTrue(shape.clips)
    }

    func testAPrefixKeepsAClassForItsPlaceSizeStateOrAppearance() {
        let style = Style(classes: "p-3 card:p-0 card:hover:hidden dark:text-accent wide:flex-row")
        XCTAssertEqual(style.padding[.top], .steps(3))
        XCTAssertNil(style.isHidden)
        XCTAssertEqual(style.variants[[.card]]?.padding[.top], .steps(0))
        XCTAssertEqual(style.variants[[.hover, .card]]?.isHidden, true)
        XCTAssertEqual(style.variants[[.dark]]?.ink, .accent)
        XCTAssertEqual(style.variants[[.wide]]?.arrangement, .row)
        XCTAssertEqual(Set(Style.Variant.allCases.map(\.rawValue)), [
            "sheet", "card", "bar", "float", "window", "small", "wide", "square", "strip", "large",
            "hover", "pressed", "selected", "focus", "dark", "light"
        ])
        XCTAssertTrue(style.unknown.isEmpty)
    }

    func testAnUnknownClassIsSkippedAndKept() {
        let style = Style(classes: "p-3 w-[120px] p-13 gap-full grid-cols-7 tall:p-2 card:glow bg-[#ff0000] text-purple")
        XCTAssertEqual(style.unknown, ["w-[120px]", "p-13", "gap-full", "grid-cols-7", "tall:p-2", "card:glow", "bg-[#ff0000]", "text-purple"])
        XCTAssertEqual(style.padding[.top], .steps(3))
        XCTAssertTrue(style.variants.isEmpty)
    }

    func testEachDistinctClassStringParsesOnceAndTheCacheKeepsAFewOnly() {
        let cache = StyleCache(limit: 2)
        XCTAssertEqual(cache.style(of: "p-3 gap-2"), Style(classes: "p-3 gap-2"))
        _ = cache.style(of: "p-3 gap-2")
        XCTAssertEqual(cache.count, 1)
        _ = cache.style(of: "p-1")
        _ = cache.style(of: "p-2")
        XCTAssertLessThanOrEqual(cache.count, 2)
    }
}
