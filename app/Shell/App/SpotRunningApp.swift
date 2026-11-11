import OpenspotCore

/// The app as the API reaches it while it runs.
struct SpotRunningApp: RunningApp {
    let model: SpotsModel

    func configChanged() async {
        await model.configChanged()
    }
}
