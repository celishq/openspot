import Foundation

/// What the sandbox shows: the text of a sheet, the sheet it draws, its faults and what a person did to it. A sheet that
/// cannot be drawn leaves the last one in place, so that typing does not make it flicker.
public struct SheetSandbox: Equatable, Sendable {
    public private(set) var text = ""
    public private(set) var panel: SheetParts?
    public private(set) var faults: [String] = []
    public private(set) var log: [String] = []

    private static let logLength = 8

    public init() {}

    /// The command that the sandbox calls for a file: it reads a file with a `read`, and clicks any other.
    public static func command(file: URL) -> Spot {
        let header = SpotHeader(url: file).block
        return Spot(
            id: file.lastPathComponent,
            name: file.lastPathComponent,
            url: file,
            kind: .list,
            read: (try? SpotRead(read: header.value("read"), every: header.value("every"), on: header.value("on"), of: file.lastPathComponent)) ?? nil,
            mode: header.value("mode").flatMap(SpotMode.init(rawValue:)).map { $0.stays ? .stay : .once } ?? .once
        )
    }

    /// Reads a sheet that a person typed or a script printed.
    public mutating func take(text: String) {
        self.text = text
        let output = SpotOutput(text: text)
        faults = text.isEmpty ? [] : output.sheetFaults
        if let panel = SheetParts(output: output) { self.panel = panel }
    }

    /// Takes a value that a person set in the sheet, and returns the generation of the call that reports it.
    @discardableResult
    public mutating func set(_ value: String, of id: String) -> Int {
        record("\(id) \(value)")
        return panel?.set(value, of: id) ?? 0
    }

    /// Takes a press in the sheet, and returns the generation of the call that reports it.
    @discardableResult
    public mutating func press(_ id: String) -> Int {
        record(id)
        return panel?.advance() ?? 0
    }

    /// Shows a frame that a script printed, which its sheet draws.
    public mutating func note(frame text: String) {
        self.text = text
        let output = SpotOutput(text: text)
        guard !output.parts.isEmpty else { return }
        faults = output.layout == nil ? output.partFaults : output.sheetFaults
    }

    public mutating func record(_ line: String) {
        log = Array((log + [line]).suffix(Self.logLength))
    }
}
