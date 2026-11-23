import Foundation

public struct SpotFiles: Sendable {
    struct File: Sendable {
        let path: String
        let isScript: Bool
        let views: [String]
    }

    private let files: [File]

    init(_ files: [File]) {
        self.files = files
    }

    init(folder: URL) {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
        let manifest = Manifest(folder: folder)
        self.init(names.map { name in
            let url = folder.appendingPathComponent(name)
            let isScript = SpotsFolder.isScript(url, manifest: manifest)
            return File(path: url.path, isScript: isScript, views: isScript ? (try? manifest.script(name))?.views ?? [] : [])
        })
    }

    init(package: SpotPackage) {
        let manifests = Dictionary(package.files.filter { ($0.path as NSString).lastPathComponent == Manifest.fileName }.map { file in
            let folder = (file.path as NSString).deletingLastPathComponent
            return (folder, Manifest(text: file.text, folder: folder))
        }) { first, _ in first }
        self.init(package.files.map { file in
            let folder = (file.path as NSString).deletingLastPathComponent
            let views = file.isExecutable ? (try? (manifests[folder] ?? Manifest(text: nil, folder: folder)).script(file.path))?.views ?? [] : []
            return File(path: file.path, isScript: file.isExecutable, views: views)
        })
    }

    var scripts: [String] {
        files.filter(\.isScript).map(\.path)
    }

    func programs(of script: String) -> [String] {
        files.map(\.path).filter { SwiftProgram.isProgram($0, of: script) }
    }

    func views(of script: String) -> [String] {
        let folder = (script as NSString).deletingLastPathComponent
        return (files.first { $0.path == script }?.views ?? []).filter { !$0.hasPrefix("/") }.compactMap { has(folder.isEmpty ? $0 : "\(folder)/\($0)") }
    }

    func libraries(of source: String) -> [String] {
        files.map(\.path).filter { ViewLibrary.isLibrary($0, of: source) }
    }

    func own(of script: String) -> [String] {
        [script] + programs(of: script) + views(of: script).flatMap { [$0] + libraries(of: $0) }
    }

    func isBuilt(_ path: String) -> Bool {
        files.contains { SwiftProgram.isProgram(path, of: $0.path) || ViewLibrary.isLibrary(path, of: $0.path) && $0.path.hasSuffix(".\(SwiftProgram.sourceExtension)") }
    }

    private func has(_ path: String) -> String? {
        files.contains { $0.path == path } ? path : nil
    }
}
