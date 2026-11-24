import Foundation

extension SpotsModel {
    func unmarkNew(_ id: String) {
        guard arrangement.mark(of: id) == .new, unmarking.insert(id).inserted else { return }
        let config = files.config
        Task { [weak self] in
            let next: Result<KeptConfig, Error> = await Self.unmark(id, in: config)
            guard let self else { return }
            unmarking.remove(id)
            switch next {
            case .success(let next): change(isShown && openSheetID == nil ? .edit : nil) { configChanged(.spots([id]), to: next) }
            case .failure(let error): host.notify("Openspot could not save the spots. \(Self.reason(error))")
            }
        }
    }

    @concurrent
    private nonisolated static func unmark(_ id: String, in config: ConfigFile) async -> Result<KeptConfig, Error> {
        Result { try config.change { $0.arrangement.set(mark: nil, of: id) } }
    }
}
