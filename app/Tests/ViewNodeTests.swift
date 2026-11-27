import XCTest
@testable import OpenspotCore

final class ViewNodeTests: XCTestCase {
    func testANodeKeepsItsStyleOutsideItself() {
        XCTAssertLessThanOrEqual(MemoryLayout<ViewNode>.stride, 528, "a node is \(MemoryLayout<ViewNode>.stride) bytes")
    }

    func testNodesOfOneClassKeepEachTheirOwnGrowth() {
        let tree = Frame(text: """
        frame=
        class=gap-3

        text=one
        title=One
        class=text-accent

        text=two
        title=Two
        class=text-accent
        grow=true

        text=three
        title=Three
        class=text-accent
        """).tree

        XCTAssertEqual(tree.node("one")?.style, tree.node("three")?.style)
        XCTAssertEqual(tree.node("one")?.style.ink, .accent)
        XCTAssertEqual(tree.node("two")?.style.ink, .accent)
        XCTAssertNil(tree.node("one")?.style.grows)
        XCTAssertEqual(tree.node("two")?.style.grows, true)
    }
}
