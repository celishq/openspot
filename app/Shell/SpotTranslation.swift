import Foundation
import NaturalLanguage
import OpenspotCore
import Translation

/// The macOS Translation framework for a script. It prints one row for each language the person prefers.
enum SpotTranslation {
    /// Prints the rows and exits. Text in a language it cannot tell prints nothing.
    static func run(text: String) -> Never {
        Task {
            await printRows(of: text)
            exit(0)
        }
        dispatchMain()
    }

    private static func printRows(of text: String) async {
        guard let source = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue else { return }
        let availability = LanguageAvailability()
        for code in TranslationTargets(preferred: Locale.preferredLanguages, source: source).codes {
            let from = Locale.Language(identifier: source)
            let to = Locale.Language(identifier: code)
            let name = Locale.current.localizedString(forLanguageCode: code) ?? code
            switch await availability.status(from: from, to: to) {
            case .installed:
                do {
                    let answer = try await TranslationSession(installedSource: from, target: to).translate(text).targetText
                    printRow(answer, detail: name, run: answer)
                } catch {
                    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                    exit(1)
                }
            case .supported:
                printRow("\(name) is not installed", detail: "Add it in System Settings", run: ":settings:\(code)", symbol: "arrow.down.circle")
            default:
                break
            }
        }
    }

    private static func printRow(_ title: String, detail: String, run: String, symbol: String? = nil) {
        var fields = [TextBlock.Field(key: "row", value: title), .init(key: "detail", value: detail), .init(key: "run", value: run)]
        if let symbol { fields.append(.init(key: "symbol", value: symbol)) }
        print(TextBlock(fields: fields).text)
    }
}
