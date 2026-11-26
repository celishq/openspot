import XCTest
@testable import OpenspotCore

@MainActor
final class AttachmentLookTests: AttachmentCase {
    private let safari = FrontApp(bundleID: "com.apple.Safari", path: "/Applications/Safari.app")
    private let safariIcon = AttachmentChip.Look.file(FileIcon(path: "/Applications/Safari.app"))
    private let picture = AttachmentChip.Look.file(.image("/spots/tab.spot/tab.png"))

    private func look(over front: FrontApp?, own: AttachmentChip.Look?, value: AttachmentValue? = nil) -> AttachmentChip.Look? {
        var stack = AttachmentStack(fit: 3)
        stack.open(over: front, unread: [("tab", own)])
        if let value { stack.fill("tab", with: value, look: own) }
        return stack.chips.first?.look
    }

    func testTheIconOfTheValueComesBeforeThePictureOfTheSpotAndTheApp() {
        let value = { (icon: String) in AttachmentValue(url: "https://a.com", app: "com.apple.Safari", icon: Icon(text: icon)) }

        XCTAssertEqual(look(over: safari, own: picture, value: value("star")), .symbol("star"))
        XCTAssertEqual(look(over: safari, own: picture, value: value("/tmp/a.png")), .file(.image("/tmp/a.png")))
        XCTAssertEqual(look(over: safari, own: picture, value: value("https://a.com/b.png")), .file(.image("https://a.com/b.png")))
        XCTAssertEqual(look(over: safari, own: picture, value: value("/Applications/Notes.app")), .file(FileIcon(path: "/Applications/Notes.app")))
        XCTAssertEqual(look(over: safari, own: picture, value: value("★")), .glyph("★"))
        XCTAssertEqual(look(over: safari, own: picture, value: value("#ff3b30")), .color("#ff3b30"))
    }

    func testThePictureOfTheSpotComesBeforeTheAppAtRestAndWithAValue() {
        XCTAssertEqual(look(over: safari, own: picture), picture)
        XCTAssertEqual(look(over: safari, own: picture, value: AttachmentValue(url: "https://a.com", app: "com.apple.Safari")), picture)
    }

    func testTheAppComesBeforeTheSymbolOfTheSpot() {
        XCTAssertEqual(look(over: safari, own: .symbol("globe")), safariIcon)
        XCTAssertEqual(look(over: safari, own: .symbol("globe"), value: AttachmentValue(url: "https://a.com", app: "com.apple.Safari")), safariIcon)
    }

    func testTheSymbolOfTheSpotShowsWithNoApp() {
        XCTAssertEqual(look(over: nil, own: .symbol("globe"), value: AttachmentValue(text: "hola")), .symbol("globe"))
        XCTAssertEqual(look(over: nil, own: nil, value: AttachmentValue(text: "hola")), .symbol(AttachmentValue.Kind.text.symbol))
    }

    func testAttachmentAddTakesAnIconInItsWordsAndOnStdin() async throws {
        try taker(takes: "'url', 'text'")
        try pickSource(runs: "\(cli) attachment add url=https://a.com icon=star")
        try pickSource("selection", runs: "printf 'text=hola\\nicon=★\\n' | \(cli) attachment add")
        await open()

        XCTAssertTrue(model.handleKey(ActionKey(name: "tab")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "tab")))

        try await wait("both values") { self.chips.count == 2 && self.chips.allSatisfy { $0.value != nil } }
        XCTAssertEqual(chips.first { $0.source == "tab" }?.value?.icon, .symbol("star"))
        XCTAssertEqual(chips.first { $0.source == "tab" }?.look, .symbol("star"))
        XCTAssertEqual(chips.first { $0.source == "selection" }?.look, .glyph("★"))
    }
}
