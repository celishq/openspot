import Foundation

public actor ViewBuilds {
    static let faultLimit = 32

    private let library: ViewLibrary
    private var building: [String: Task<URL, Error>] = [:]
    private var faults: [String: SpotError] = [:]
    private var faultOrder: [String] = []

    public init(library: ViewLibrary = .standard()) {
        self.library = library
    }

    var faultCount: Int {
        faults.count
    }

    public func library(of source: URL) async throws -> URL {
        guard let text = try? Data(contentsOf: source) else {
            throw SpotError.fault("Openspot cannot find the view \(source.lastPathComponent).")
        }
        let name = ViewLibrary.name(of: text)
        if let fault = faults[name] { throw fault }
        if let build = building[name] { return try await build.value }
        let build = Task { [library] in try await library.library(of: source, text: text) }
        building[name] = build
        defer { building[name] = nil }
        do {
            return try await build.value
        } catch let fault as SpotError where fault.reason.hasPrefix(ViewLibrary.sourceFault) {
            keep(fault, of: name)
            throw fault
        }
    }

    private func keep(_ fault: SpotError, of name: String) {
        faults[name] = fault
        faultOrder.append(name)
        while faultOrder.count > Self.faultLimit { faults[faultOrder.removeFirst()] = nil }
    }
}
