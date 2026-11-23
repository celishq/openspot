import Observation
import OpenspotCore

@MainActor
@Observable
final class WorkCardStage {
    var card: WorkCard?
    var isShown = false
}
