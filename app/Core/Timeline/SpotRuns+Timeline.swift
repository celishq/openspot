import Foundation

extension SpotRuns {
    func timeNow() -> Date {
        now()
    }

    func timelineChanged(_ spot: String, by changer: String?) {
        for reader in timeline.readers(of: spot) where reader != changer {
            guard let sheet = sheets[reader], sheet.isOpen else { continue }
            sheet.show(need: .change)
        }
    }
}
