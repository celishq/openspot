import Foundation
import OpenspotCore

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: openspot-views <spots folder>\n".utf8))
    exit(2)
}
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let cache = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-views-\(UUID().uuidString)", isDirectory: true)
Task {
    do {
        for library in try await ViewLibrary(cache: cache).buildViews(under: folder) {
            print(library.path)
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\((error as? SpotError)?.reason ?? error.localizedDescription)\n".utf8))
        exit(1)
    }
}
dispatchMain()
