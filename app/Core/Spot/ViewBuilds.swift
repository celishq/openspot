import Foundation

public actor ViewBuilds {
    static let faultLimit = 32
    private static let shownWord = Data("isShown".utf8)
    private static let selectionWord = Data("selection".utf8)

    private let library: ViewLibrary
    private var building: [String: Task<URL, Error>] = [:]
    private var faults: [String: SpotError] = [:]
    private var faultOrder: [String] = []
    private var toolsFault: SpotError?

    public init(library: ViewLibrary = .standard()) {
        self.library = library
    }

    var faultCount: Int {
        faults.count
    }

    public func library(of source: URL) async throws -> URL {
        try await built(of: source).library
    }

    public func built(of source: URL) async throws -> (library: URL, readsShown: Bool, readsSelection: Bool) {
        guard let text = try? Data(contentsOf: source) else {
            throw SpotError.fault("Openspot cannot find the view \(source.lastPathComponent).")
        }
        return (try await library(of: source, text: text), text.range(of: Self.shownWord) != nil, text.range(of: Self.selectionWord) != nil)
    }

    private func library(of source: URL, text: Data) async throws -> URL {
        let name = ViewLibrary.name(of: text)
        if let fault = faults[name] { throw fault }
        if let build = building[name] { return try await build.value }
        if let kept = library.kept(of: source, text: text) { return kept }
        if let toolsFault { throw toolsFault }
        let build = Task { [library] in try await library.library(of: source, text: text) }
        building[name] = build
        defer { building[name] = nil }
        do {
            return try await build.value
        } catch let fault as SpotError {
            if fault.reason == ViewLibrary.toolsFault { toolsFault = fault }
            if fault.reason.hasPrefix("\(ViewLibrary.sourceFault) \(source.lastPathComponent):"), fault.reason.contains("error:") { keep(fault, of: name) }
            throw fault
        }
    }

    private func keep(_ fault: SpotError, of name: String) {
        faults[name] = fault
        faultOrder.append(name)
        while faultOrder.count > Self.faultLimit { faults[faultOrder.removeFirst()] = nil }
    }
}
