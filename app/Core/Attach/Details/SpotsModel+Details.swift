import Foundation

extension SpotsModel {
    func shownDetails(of query: String, in stack: AttachmentStack? = nil) -> AttachmentDetails? {
        let stack = stack ?? attachments
        guard showsAttachment(of: query, in: stack), let chip = stack.selectedChip, entry(chip.source) != nil else { return nil }
        return chip.details
    }

    static func room(of details: AttachmentDetails?) -> CGFloat {
        details.map { SpotTokens.detailsHeight(lines: $0.lines) } ?? 0
    }

    func detailsMotion(to shown: AttachmentDetails?, else motion: PanelMotion?) -> PanelMotion? {
        let room = Self.room(of: shown)
        return room == detailsRoom ? motion : .sheet(isOpen: room > detailsRoom)
    }

    func takeDetails(_ shown: AttachmentDetails?) {
        if details != shown { details = shown }
    }

    func takeDetails() {
        takeDetails(shownDetails(of: query))
    }

    func showDetails(_ shown: AttachmentDetails?, with rest: () -> Void = {}) {
        guard shown != details else { return rest() }
        change(isShown ? detailsMotion(to: shown, else: .edit) : nil) {
            takeDetails(shown)
            rest()
        }
    }
}
