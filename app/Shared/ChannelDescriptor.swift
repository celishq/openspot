import Darwin

enum ChannelDescriptor {
    static let number: Int32 = 11
    static let ready: UInt8 = 6

    private static let header = (MemoryLayout<cmsghdr>.size + 3) & ~3
    private static let space = header + MemoryLayout<Int32>.size

    static func isChannel(_ descriptor: Int32) -> Bool {
        var type: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(descriptor, SOL_SOCKET, SO_TYPE, &type, &size) == 0, type == SOCK_DGRAM else { return false }
        var address = sockaddr_storage()
        var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        return named == 0 && address.ss_family == sa_family_t(AF_UNIX)
    }

    static func send(_ descriptor: Int32, over socket: Int32, tries: Int = 400) -> Bool {
        for _ in 0..<tries {
            if sendOnce(descriptor, over: socket) { return true }
            guard errno == ENOBUFS || errno == EAGAIN || errno == EINTR else { return false }
            usleep(5_000)
        }
        return false
    }

    private static func sendOnce(_ descriptor: Int32, over socket: Int32) -> Bool {
        var byte: UInt8 = 0
        var control = [UInt8](repeating: 0, count: space)
        control.withUnsafeMutableBytes { bytes in
            let head = bytes.baseAddress!.assumingMemoryBound(to: cmsghdr.self)
            head.pointee = cmsghdr(cmsg_len: socklen_t(space), cmsg_level: SOL_SOCKET, cmsg_type: SCM_RIGHTS)
            bytes.storeBytes(of: descriptor, toByteOffset: header, as: Int32.self)
        }
        return withUnsafeMutablePointer(to: &byte) { pointer in
            var vector = iovec(iov_base: pointer, iov_len: 1)
            return control.withUnsafeMutableBytes { bytes in
                withUnsafeMutablePointer(to: &vector) { vectors in
                    var message = msghdr(msg_name: nil, msg_namelen: 0, msg_iov: vectors, msg_iovlen: 1, msg_control: bytes.baseAddress, msg_controllen: socklen_t(space), msg_flags: 0)
                    return sendmsg(socket, &message, 0) == 1
                }
            }
        }
    }

    static func receive(from socket: Int32) -> [Int32]? {
        var byte: UInt8 = 0
        let room = header + 256 * MemoryLayout<Int32>.size
        var control = [UInt8](repeating: 0, count: room)
        let (count, length) = withUnsafeMutablePointer(to: &byte) { pointer in
            var vector = iovec(iov_base: pointer, iov_len: 1)
            return control.withUnsafeMutableBytes { bytes in
                withUnsafeMutablePointer(to: &vector) { vectors in
                    var message = msghdr(msg_name: nil, msg_namelen: 0, msg_iov: vectors, msg_iovlen: 1, msg_control: bytes.baseAddress, msg_controllen: socklen_t(room), msg_flags: 0)
                    let count = recvmsg(socket, &message, 0)
                    return (count, Int(message.msg_controllen))
                }
            }
        }
        guard count >= 0 else { return nil }
        var descriptors: [Int32] = []
        var offset = 0
        control.withUnsafeBytes { bytes in
            while offset + MemoryLayout<cmsghdr>.size <= min(length, room) {
                let head = bytes.load(fromByteOffset: offset, as: cmsghdr.self)
                let size = Int(head.cmsg_len)
                guard size >= header, offset + size <= room else { break }
                if head.cmsg_level == SOL_SOCKET, head.cmsg_type == SCM_RIGHTS {
                    for index in 0..<(size - header) / MemoryLayout<Int32>.size {
                        descriptors.append(bytes.load(fromByteOffset: offset + header + index * MemoryLayout<Int32>.size, as: Int32.self))
                    }
                }
                offset += (size + 3) & ~3
            }
        }
        return descriptors
    }
}
