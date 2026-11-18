import Foundation

final class RunChannel: @unchecked Sendable {
    private let lock = NSLock()
    private let own: Int32
    private var child: Int32
    private let queue = DispatchQueue(label: "dev.openspot.channel")
    private let source: any DispatchSourceRead
    private let serve: @Sendable (Int32) -> Void

    init?(serve: @escaping @Sendable (Int32) -> Void) {
        var pair: [Int32] = [-1, -1]
        guard socketpair(AF_UNIX, SOCK_DGRAM, 0, &pair) == 0 else { return nil }
        own = pair[0]
        child = pair[1]
        self.serve = serve
        _ = fcntl(own, F_SETFD, FD_CLOEXEC)
        _ = fcntl(child, F_SETFD, FD_CLOEXEC)
        _ = fcntl(own, F_SETFL, O_NONBLOCK)
        source = DispatchSource.makeReadSource(fileDescriptor: own, queue: queue)
        source.setEventHandler { [weak self] in self?.take() }
        source.setCancelHandler { [own] in Darwin.close(own) }
        source.resume()
    }

    var childEnd: Int32? {
        lock.withLock { child >= 0 ? child : nil }
    }

    func close() {
        lock.withLock {
            guard child >= 0 else { return }
            Darwin.close(child)
            child = -1
        }
        queue.async { [self] in
            take()
            source.cancel()
        }
    }

    private func take() {
        while let descriptors = ChannelDescriptor.receive(from: own) {
            for (index, descriptor) in descriptors.enumerated() {
                guard index == 0, Self.isStream(descriptor) else {
                    Darwin.close(descriptor)
                    continue
                }
                _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
                SocketOption.quiet(descriptor)
                var ready = ChannelDescriptor.ready
                guard write(descriptor, &ready, 1) == 1 else {
                    Darwin.close(descriptor)
                    continue
                }
                serve(descriptor)
            }
        }
    }

    private static func isStream(_ descriptor: Int32) -> Bool {
        var type: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        return getsockopt(descriptor, SOL_SOCKET, SO_TYPE, &type, &size) == 0 && type == SOCK_STREAM
    }
}
