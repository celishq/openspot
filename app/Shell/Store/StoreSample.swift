import OpenspotCore

struct StoreSample {
    let id: String
    let output: Frame
    let hasSheet: Bool

    @MainActor
    init(id: String, output: Frame) {
        self.id = id
        self.output = output
        hasSheet = !SheetParts(output: output).parts.isEmpty || !SpotSheetPicture.list(of: output).shown.isEmpty
    }
}
