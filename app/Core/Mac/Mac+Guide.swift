import Foundation

extension Mac {
    func readGuide() throws -> Guide {
        guard let file = guide else { throw SpotError.fault("This copy of Openspot has no guide. Install Openspot again.") }
        let names = pages.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) } ?? []
        let texts = try Dictionary(uniqueKeysWithValues: names.filter { $0.pathExtension == "md" }.map { ($0.deletingPathExtension().lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) })
        return Guide(text: try String(contentsOf: file, encoding: .utf8), pages: texts)
    }
}
