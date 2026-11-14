import Foundation
import OpenspotCore
import SwiftUI

@MainActor
@Observable
final class SpotViews {
    typealias Make = ([String: [String]], [String: Any], @escaping (String) -> Void) -> AnyView

    enum Phase {
        case building
        case ready(Make)
        case failed(String)
    }

    private(set) var phases: [String: Phase] = [:]
    @ObservationIgnored private var loaded: [URL: Make] = [:]
    @ObservationIgnored private var libraries: [String: URL] = [:]
    @ObservationIgnored private let library: ViewLibrary

    static let shared = SpotViews()

    init(library: ViewLibrary = .standard()) {
        self.library = library
    }

    func phase(of source: String) -> Phase {
        phases[source] ?? .building
    }

    func load(_ source: String) async {
        let library = library
        do {
            let url = try await Task.detached { try await library.library(of: URL(fileURLWithPath: source)) }.value
            if let make = loaded[url] {
                if libraries[source] != url { ready(source, make, from: url) }
                return
            }
            let entry = try await Task.detached { try Self.entry(of: url) }.value
            let object = Unmanaged<AnyObject>.fromOpaque(entry()).takeRetainedValue()
            guard let make = object as? Make else { throw SpotError.fault("This view has an entry that Openspot cannot read. Build it again.") }
            loaded[url] = make
            ready(source, make, from: url)
        } catch {
            libraries[source] = nil
            phases[source] = .failed((error as? SpotError)?.reason ?? error.localizedDescription)
        }
    }

    private func ready(_ source: String, _ make: @escaping Make, from url: URL) {
        libraries[source] = url
        phases[source] = .ready(make)
    }

    private nonisolated static func entry(of url: URL) throws -> @convention(c) () -> UnsafeMutableRawPointer {
        guard let handle = dlopen(url.path, RTLD_NOW | RTLD_LOCAL) else {
            throw SpotError.fault("Openspot cannot load this view. \(String(cString: dlerror()))")
        }
        guard let symbol = dlsym(handle, ViewLibrary.entry) else {
            throw SpotError.fault("This view has no entry. Build it again.")
        }
        return unsafeBitCast(symbol, to: (@convention(c) () -> UnsafeMutableRawPointer).self)
    }
}
