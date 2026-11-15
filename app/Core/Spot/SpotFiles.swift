import Foundation

public struct SpotFiles: Sendable {
    struct File: Sendable {
        let path: String
        let isScript: Bool
        let view: String?
    }

    private let files: [File]

    init(_ files: [File]) {
        self.files = files
    }

    init(folder: URL) {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
        self.init(names.map { name in
            let url = folder.appendingPathComponent(name)
            let isScript = SpotsFolder.isScript(url)
            return File(path: url.path, isScript: isScript, view: isScript ? SpotHeader(url: url).block.value(HeaderKey.view) : nil)
        })
    }

    init(package: SpotPackage) {
        self.init(package.files.map { file in
            let view = file.isExecutable ? file.text.flatMap { SpotHeader(text: $0).block.value(HeaderKey.view) } : nil
            return File(path: file.path, isScript: file.isExecutable, view: view)
        })
    }

    var scripts: [String] {
        files.filter(\.isScript).map(\.path)
    }

    func programs(of script: String) -> [String] {
        files.map(\.path).filter { SwiftProgram.isProgram($0, of: script) }
    }

    func view(of script: String) -> String? {
        guard let name = files.first(where: { $0.path == script })?.view, !name.hasPrefix("/") else { return nil }
        let folder = (script as NSString).deletingLastPathComponent
        return has(folder.isEmpty ? name : "\(folder)/\(name)")
    }

    func libraries(of source: String) -> [String] {
        files.map(\.path).filter { ViewLibrary.isLibrary($0, of: source) }
    }

    func own(of script: String) -> [String] {
        let view = view(of: script)
        return [script] + programs(of: script) + (view.map { [$0] + libraries(of: $0) } ?? [])
    }

    func isBuilt(_ path: String) -> Bool {
        files.contains { SwiftProgram.isProgram(path, of: $0.path) || ViewLibrary.isLibrary(path, of: $0.path) && $0.path.hasSuffix(".\(SwiftProgram.sourceExtension)") }
    }

    private func has(_ path: String) -> String? {
        files.contains { $0.path == path } ? path : nil
    }
}
