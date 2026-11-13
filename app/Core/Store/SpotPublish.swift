/// What a publish to the store did: it wrote a package, found no change since the last one, asked for a readme first, met a
/// spot that is not a file of the spots folder, or failed.
public enum SpotPublish: Equatable, Sendable {
    case published, unchanged, needsReadme, notOwn, failed
}
