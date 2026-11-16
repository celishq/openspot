import Foundation

extension Mac {
    func readGuide() throws -> Guide {
        guard let file = guide else { throw SpotError.fault("This copy of Openspot has no guide. Install Openspot again.") }
        return Guide(text: try String(contentsOf: file, encoding: .utf8), pages: readPages())
    }

    func readPages() -> [String: String] {
        let names = pages.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) } ?? []
        return Dictionary(uniqueKeysWithValues: names.filter { $0.pathExtension == "md" }.compactMap { url in
            (try? String(contentsOf: url, encoding: .utf8)).map { (url.deletingPathExtension().lastPathComponent, $0) }
        })
    }
}
