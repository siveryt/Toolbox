//
//  Traceroute.swift
//  Toolbox
//
//  Finds the routers between this device and a host: ICMP echo requests are sent with a growing
//  time to live (TTL), and every router that drops one because its TTL ran out answers with
//  "time exceeded", which tells its address. The destination itself answers with an echo reply.
//

import Foundation
import Darwin

/// One router (or the destination) on the way to the host.
struct TracerouteHop: Identifiable, Equatable {
    /// The TTL the probes were sent with, which is the hop's position on the route.
    let ttl: Int
    /// The address that answered, nil if no probe got an answer.
    var address: String?
    /// The round-trip time of each probe in milliseconds, nil for a probe without answer.
    var times: [Double?]
    /// The answer came from the host itself (or it said it can't be reached), so the route ends here.
    var isDestination: Bool

    var id: Int { ttl }

    var answeredTimes: [Double] { times.compactMap { $0 } }

    var averageTime: Double? {
        let answered = answeredTimes
        return answered.isEmpty ? nil : answered.reduce(0, +) / Double(answered.count)
    }
}

enum TracerouteError: Error {
    case hostNotFound
    case socketFailed
}

enum Traceroute {
    static let maxHops = 30
    static let probesPerHop = 3
    /// How long to wait for the answer to one probe.
    static let probeTimeout: Double = 1.5

    /// The IPv4 address of a host name or address, like SwiftyPing (which the Ping tool uses) only works with IPv4.
    static func resolve(_ host: String) throws -> in_addr {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let result else {
            throw TracerouteError.hostNotFound
        }
        defer { freeaddrinfo(result) }
        guard let address = result.pointee.ai_addr, result.pointee.ai_family == AF_INET else {
            throw TracerouteError.hostNotFound
        }
        return address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
    }

    static func string(from address: in_addr) -> String {
        var address = address
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buffer)
    }

    /// The host name of an address (reverse DNS), nil if it has none. Blocks, so call it off the main thread.
    static func hostName(of address: String) -> String? {
        var socketAddress = sockaddr_in()
        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = sa_family_t(AF_INET)
        guard inet_pton(AF_INET, address, &socketAddress.sin_addr) == 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let status = withUnsafePointer(to: &socketAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getnameinfo($0, socklen_t(MemoryLayout<sockaddr_in>.size), &buffer, socklen_t(buffer.count), nil, 0, NI_NAMEREQD)
            }
        }
        guard status == 0 else { return nil }
        let name = String(cString: buffer)
        return name == address ? nil : name
    }

    /// Traces the route to `destination`, delivering each hop when all its probes are done.
    /// Cancelling the task that iterates the stream stops the trace.
    static func trace(to destination: in_addr) -> AsyncThrowingStream<TracerouteHop, Error> {
        AsyncThrowingStream { continuation in
            let thread = Thread {
                do {
                    try run(to: destination) { hop in
                        continuation.yield(hop)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                thread.cancel()
            }
            thread.qualityOfService = .userInitiated
            thread.start()
        }
    }

    /// The blocking trace, run on its own thread.
    private static func run(to destination: in_addr, onHop: (TracerouteHop) -> Void) throws {
        // An ICMP datagram socket needs no special rights, unlike a raw socket.
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard fd >= 0 else { throw TracerouteError.socketFailed }
        defer { close(fd) }

        var target = sockaddr_in()
        target.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        target.sin_family = sa_family_t(AF_INET)
        target.sin_addr = destination

        let identifier = UInt16.random(in: 0...UInt16.max)
        var sequence: UInt16 = 0

        for ttl in 1...maxHops {
            var value = Int32(ttl)
            guard setsockopt(fd, IPPROTO_IP, IP_TTL, &value, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
                throw TracerouteError.socketFailed
            }
            var hop = TracerouteHop(ttl: ttl, address: nil, times: [], isDestination: false)
            for _ in 0..<probesPerHop {
                if Thread.current.isCancelled { return }
                sequence &+= 1
                let answer = probe(fd: fd, target: target, identifier: identifier, sequence: sequence)
                hop.times.append(answer?.time)
                if let answer {
                    hop.address = hop.address ?? answer.address
                    hop.isDestination = hop.isDestination || answer.isFinal
                }
            }
            if Thread.current.isCancelled { return }
            onHop(hop)
            if hop.isDestination { return }
        }
    }

    private struct Answer {
        let address: String
        let time: Double
        /// An echo reply or "destination unreachable": no point in going further.
        let isFinal: Bool
    }

    /// Sends one echo request and waits for the answer that belongs to it.
    private static func probe(fd: Int32, target: sockaddr_in, identifier: UInt16, sequence: UInt16) -> Answer? {
        var target = target
        let packet = echoRequest(identifier: identifier, sequence: sequence)
        let start = DispatchTime.now().uptimeNanoseconds
        let sent = packet.withUnsafeBytes { bytes in
            withUnsafePointer(to: &target) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, bytes.baseAddress, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == packet.count else { return nil }

        let deadline = start + UInt64(probeTimeout * 1_000_000_000)
        var buffer = [UInt8](repeating: 0, count: 1500)
        while true {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline, !Thread.current.isCancelled else { return nil }
            var pollDescriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            // Wake up at least every 100 ms, so cancelling doesn't wait for the timeout.
            let wait = Int32(min((deadline - now) / 1_000_000, 100))
            let ready = poll(&pollDescriptor, 1, max(wait, 1))
            guard ready > 0 else { continue }

            var source = sockaddr_in()
            var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let received = withUnsafeMutablePointer(to: &source) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(fd, &buffer, buffer.count, 0, $0, &sourceLength)
                }
            }
            guard received > 0 else { continue }
            let time = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            guard let kind = match(Array(buffer[0..<received]), identifier: identifier, sequence: sequence) else {
                // An answer to another probe (a late one, or another app's ping); keep waiting.
                continue
            }
            return Answer(address: string(from: source.sin_addr), time: time, isFinal: kind != .timeExceeded)
        }
    }

    private enum Kind { case echoReply, timeExceeded, unreachable }

    /// What a received packet says about our probe, nil if it belongs to another one.
    private static func match(_ packet: [UInt8], identifier: UInt16, sequence: UInt16) -> Kind? {
        // On Darwin an ICMP datagram socket gets the packet with its IP header.
        let offset = ipHeaderLength(packet)
        guard packet.count >= offset + 8 else { return nil }
        let type = packet[offset]
        switch type {
        case 0: // echo reply
            guard readUInt16(packet, offset + 4) == identifier, readUInt16(packet, offset + 6) == sequence else { return nil }
            return .echoReply
        case 11, 3: // time exceeded, destination unreachable: they quote the IP header and the first 8 bytes of our request
            let quoted = Array(packet[(offset + 8)...])
            let quotedOffset = ipHeaderLength(quoted)
            guard quoted.count >= quotedOffset + 8, quoted[quotedOffset] == 8,
                  readUInt16(quoted, quotedOffset + 4) == identifier,
                  readUInt16(quoted, quotedOffset + 6) == sequence else { return nil }
            return type == 11 ? .timeExceeded : .unreachable
        default:
            return nil
        }
    }

    /// The length of the IPv4 header at the start of the packet, 0 if it doesn't start with one.
    private static func ipHeaderLength(_ packet: [UInt8]) -> Int {
        guard let first = packet.first, first >> 4 == 4 else { return 0 }
        return Int(first & 0x0F) * 4
    }

    private static func readUInt16(_ bytes: [UInt8], _ index: Int) -> UInt16 {
        UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
    }

    /// An ICMP echo request with a small payload.
    private static func echoRequest(identifier: UInt16, sequence: UInt16) -> [UInt8] {
        var packet: [UInt8] = [8, 0, 0, 0,
                               UInt8(identifier >> 8), UInt8(identifier & 0xFF),
                               UInt8(sequence >> 8), UInt8(sequence & 0xFF)]
        packet += Array("Toolbox traceroute".utf8)
        let checksum = internetChecksum(packet)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)
        return packet
    }

    private static func internetChecksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var index = 0
        while index + 1 < bytes.count {
            sum += UInt32(bytes[index]) << 8 | UInt32(bytes[index + 1])
            index += 2
        }
        if index < bytes.count {
            sum += UInt32(bytes[index]) << 8
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(sum)
    }
}
