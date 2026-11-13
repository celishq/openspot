import Foundation
import OpenspotCore

/// Builds the view of each core spot into the app while it builds: `openspot-views <folder of spot folders> <cache>`.
/// It does not ship.
let arguments = CommandLine.arguments.dropFirst()
guard arguments.count == 2, let folder = arguments.first, let cache = arguments.last else {
    FileHandle.standardError.write(Data("Use: openspot-views <folder of spot folders> <cache folder>\n".utf8))
    exit(2)
}
Task.detached {
    do {
        print(try await ViewLibrary(cache: URL(fileURLWithPath: cache, isDirectory: true)).ship(in: URL(fileURLWithPath: folder, isDirectory: true)), terminator: "")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\((error as? SpotError)?.reason ?? String(describing: error))\n".utf8))
        exit(1)
    }
}
dispatchMain()
