import Foundation

extension SpotRuns {
    func ask(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespaces)
        answerWaits = []
        for sheet in sheets.values {
            guard let pattern = sheet.spot.triggers.search else { continue }
            sheet.answer(!text.isEmpty && answerMatches.matches(pattern, text) ? text : "")
        }
        let waits = answerWaits ?? []
        answerWaits = nil
        let deadline = DispatchTime.now() + frameWait
        waits.forEach { $0(deadline) }
    }
}
