import Foundation
import OpenspotCore
import SwiftUI

/// The views of spots, each one building, ready or failed, by the path of its source. A library stays loaded until the
/// app quits, so an edit of a view loads a new library beside the old one.
@MainActor
@Observable
final class SpotViews {
    /// The function of a library that makes its view from the values, the card and a send.
    typealias Make = ([String: [String]], [String: Any], @escaping (String) -> Void) -> AnyView

    enum Phase {
        case building
        case ready(Make)
        case failed(String)
    }

    private(set) var phases: [String: Phase] = [:]
    @ObservationIgnored private var loaded: [URL: Make] = [:]
    /// The library that each ready source was made from.
    @ObservationIgnored private var made: [String: URL] = [:]
    @ObservationIgnored private let library: ViewLibrary

    /// The one set of spot views that every card draws from.
    static let shared = SpotViews()

    init(library: ViewLibrary = .standard()) {
        self.library = library
    }

    func phase(of source: String) -> Phase {
        phases[source] ?? .building
    }

    /// Builds the view of a source when it changed, and loads its library. A view that is ready stays while its next build
    /// runs, and a view that is ready from the same library tells no card.
    func load(_ source: String) async {
        let library = library
        do {
            let url = try await Task.detached { try await library.library(of: URL(fileURLWithPath: source)) }.value
            if let make = loaded[url] {
                if made[source] != url { ready(source, make, from: url) }
                return
            }
            let entry = try await Task.detached { try Self.entry(of: url) }.value
            let object = Unmanaged<AnyObject>.fromOpaque(entry()).takeRetainedValue()
            guard let make = object as? Make else { throw SpotError.fault("This view has an entry that Openspot cannot read. Build it again.") }
            loaded[url] = make
            ready(source, make, from: url)
        } catch {
            made[source] = nil
            phases[source] = .failed((error as? SpotError)?.reason ?? error.localizedDescription)
        }
    }

    private func ready(_ source: String, _ make: @escaping Make, from url: URL) {
        made[source] = url
        phases[source] = .ready(make)
    }

    /// Opens a library and finds its entry.
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
