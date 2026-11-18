import Foundation

final class RunChannel: @unchecked Sendable {
    private let lock = NSLock()
    private let own: Int32
    private var child: Int32
    private let source: any DispatchSourceRead

    init?(serve: @escaping @Sendable (Int32) -> Void) {
        var pair: [Int32] = [-1, -1]
        guard socketpair(AF_UNIX, SOCK_DGRAM, 0, &pair) == 0 else { return nil }
        own = pair[0]
        child = pair[1]
        _ = fcntl(own, F_SETFD, FD_CLOEXEC)
        _ = fcntl(child, F_SETFD, FD_CLOEXEC)
        _ = fcntl(own, F_SETFL, O_NONBLOCK)
        source = DispatchSource.makeReadSource(fileDescriptor: own, queue: DispatchQueue(label: "dev.openspot.channel"))
        source.setEventHandler { [own] in
            while let descriptor = ChannelDescriptor.receive(from: own) {
                guard descriptor >= 0 else { continue }
                _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
                serve(descriptor)
            }
        }
        source.setCancelHandler { [own] in Darwin.close(own) }
        source.resume()
    }

    var childEnd: Int32? {
        lock.withLock { child >= 0 ? child : nil }
    }

    func spawned() {
        lock.withLock {
            guard child >= 0 else { return }
            Darwin.close(child)
            child = -1
        }
    }

    func close() {
        spawned()
        source.cancel()
    }
}
