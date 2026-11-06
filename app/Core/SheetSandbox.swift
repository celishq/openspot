import Foundation

/// What the sandbox shows: the text of a sheet, the sheet it draws, its faults and what a person did to it. A sheet that
/// cannot be drawn leaves the last one in place, so that typing does not make it flicker.
public struct SheetSandbox: Equatable, Sendable {
    public private(set) var text = ""
    public private(set) var panel: SpotPanel?
    public private(set) var faults: [String] = []
    public private(set) var log: [String] = []

    private static let logLength = 8

    public init() {}

    /// Reads a sheet that a person typed or a script printed.
    public mutating func take(text: String) {
        self.text = text
        let output = PluginOutput(text: text)
        faults = text.isEmpty ? [] : output.sheetFaults
        if let panel = SpotPanel(output: output) { self.panel = panel }
    }

    /// Takes a value that a person set in the sheet, and returns the generation of the call that reports it.
    @discardableResult
    public mutating func set(_ value: String, of id: String) -> Int {
        record("set \(id) \(value)")
        return panel?.set(value, of: id) ?? 0
    }

    /// Takes a press in the sheet, and returns the generation of the call that reports it.
    @discardableResult
    public mutating func press(_ id: String) -> Int {
        record("press \(id)")
        return panel?.advance() ?? 0
    }

    /// Takes what a script answered, unless a newer change has outdated it.
    public mutating func take(answer text: String, answering generation: Int, keeping id: String? = nil) {
        guard panel?.generation == generation || panel == nil else { return }
        self.text = text
        let output = PluginOutput(text: text)
        faults = output.sheetFaults
        if panel?.take(output, answering: generation, keeping: id) != true, let panel = SpotPanel(output: output) { self.panel = panel }
    }

    /// Takes a frame of a stream, which changes the parts it names, or the whole sheet when it has a layout.
    public mutating func merge(frame text: String, answering generation: Int? = nil, keeping id: String? = nil) {
        self.text = text
        let output = PluginOutput(text: text)
        guard !output.parts.isEmpty else { return }
        faults = output.layout == nil ? output.partFaults.filter { !$0.hasPrefix("the sheet") } : output.sheetFaults
        if panel == nil {
            panel = SpotPanel(output: output)
        } else {
            panel?.merge(output, answering: generation, keeping: id)
        }
    }

    public mutating func record(_ line: String) {
        log = Array((log + [line]).suffix(Self.logLength))
    }
}
