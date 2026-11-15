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
    @ObservationIgnored private let builds: ViewBuilds
    @ObservationIgnored private var kept: Set<String> = []

    static let shared = SpotViews()

    init(library: ViewLibrary = .standard()) {
        builds = ViewBuilds(library: library)
        phases[AccountSheet.card] = .ready(PublisherCard.make)
    }

    func phase(of source: String) -> Phase {
        phases[source] ?? .building
    }

    func isKept(_ source: String) -> Bool {
        kept.contains(source)
    }

    func load(_ source: String) async {
        if source == AccountSheet.card { return }
        do {
            let built = try await builds.built(of: URL(fileURLWithPath: source))
            let url = built.library
            if let make = loaded[url] {
                if libraries[source] != url { ready(source, make, from: url, readsShown: built.readsShown) }
                return
            }
            let entry = try await Task.detached { try Self.entry(of: url) }.value
            let object = Unmanaged<AnyObject>.fromOpaque(entry()).takeRetainedValue()
            guard let make = object as? Make else { throw SpotError.fault("This view has an entry that Openspot cannot read. Build it again.") }
            loaded[url] = make
            ready(source, make, from: url, readsShown: built.readsShown)
        } catch {
            libraries[source] = nil
            let reason = (error as? SpotError)?.reason ?? error.localizedDescription
            if case .failed(let kept)? = phases[source], kept == reason { return }
            phases[source] = .failed(reason)
        }
    }

    private func ready(_ source: String, _ make: @escaping Make, from url: URL, readsShown: Bool) {
        libraries[source] = url
        if readsShown { kept.insert(source) } else { kept.remove(source) }
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
