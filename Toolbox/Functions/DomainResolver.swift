//
//  DomainResolver.swift
//  Toolbox
//
//  Created by Christian Nagel on 17.03.22.
//

import SwiftUI
import Network
import Haptica
import ToastSwiftUI
import AsyncDNSResolver

/// The DNS server the Domain Resolver asks.
enum DNSServerChoice: String, CaseIterable, Identifiable {
    case system, cloudflare, google, quad9, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: NSLocalizedString("System", comment: "Domain Resolver: DNS server option that uses the DNS server the device's network is set up with")
        case .cloudflare: "Cloudflare (1.1.1.1)"
        case .google: "Google (8.8.8.8)"
        case .quad9: "Quad9 (9.9.9.9)"
        case .custom: NSLocalizedString("Custom", comment: "Domain Resolver: DNS server option to enter the IP address of any DNS server")
        }
    }

    /// The servers of a public DNS service, IPv4 first so it also works on networks without IPv6.
    var presetServers: [String]? {
        switch self {
        case .cloudflare: ["1.1.1.1", "1.0.0.1", "[2606:4700:4700::1111]:53"]
        case .google: ["8.8.8.8", "8.8.4.4", "[2001:4860:4860::8888]:53"]
        case .quad9: ["9.9.9.9", "149.112.112.112", "[2620:fe::fe]:53"]
        case .system, .custom: nil
        }
    }
}

/// The record types the Domain Resolver looks up, in the order they are shown.
enum DNSRecordType: String, CaseIterable, Identifiable {
    case a, aaaa, cname, mx, txt, ns, soa, ptr

    var id: String { rawValue }

    static let forward: [DNSRecordType] = [.a, .aaaa, .cname, .mx, .txt, .ns, .soa]

    var title: String {
        switch self {
        case .a: NSLocalizedString("IPv4 Addresses (A)", comment: "Domain Resolver: section header for A records")
        case .aaaa: NSLocalizedString("IPv6 Addresses (AAAA)", comment: "Domain Resolver: section header for AAAA records")
        case .cname: NSLocalizedString("Alias (CNAME)", comment: "Domain Resolver: section header for the CNAME record, the domain this one is an alias of")
        case .mx: NSLocalizedString("Mail Servers (MX)", comment: "Domain Resolver: section header for MX records")
        case .txt: NSLocalizedString("Text Records (TXT)", comment: "Domain Resolver: section header for TXT records")
        case .ns: NSLocalizedString("Name Servers (NS)", comment: "Domain Resolver: section header for NS records")
        case .soa: NSLocalizedString("Zone Authority (SOA)", comment: "Domain Resolver: section header for the SOA record")
        case .ptr: NSLocalizedString("Host Name (PTR)", comment: "Domain Resolver: section header for the reverse lookup result of an IP address")
        }
    }
}

/// One line of a lookup result.
struct DNSAnswer: Hashable, Identifiable {
    /// Shown in front of the value (SOA fields).
    var label: String? = nil
    var value: String
    /// Shown small below the value (TTL, MX priority).
    var detail: String? = nil

    var id: String { (label ?? "") + "|" + value }
}

/// The DNS queries, kept outside the view so they don't run on the main actor.
enum DNSLookup {
    /// "No such name" / "no such record" from dnssd or c-ares – the domain has no record of that type.
    static func isNotFound(_ error: Error) -> Bool {
        let source = (error as? AsyncDNSResolver.Error)?.source
        if let code = (source as? DNSSDError)?.code {
            return code == -65538 /* kDNSServiceErr_NoSuchName */ || code == -65554 /* kDNSServiceErr_NoSuchRecord */
        }
        if let code = (source as? CAresError)?.code {
            return code == 1 /* ARES_ENODATA */ || code == 4 /* ARES_ENOTFOUND */
        }
        return false
    }

    /// The host of what was typed, so a pasted link like "https://example.com/page" resolves too.
    static func host(of input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("://"), let host = URL(string: trimmed)?.host(), !host.isEmpty {
            return host
        }
        return trimmed
    }

    /// The `in-addr.arpa` / `ip6.arpa` name to look up the host name of an IP address, or nil if the input is no IP address.
    static func reverseName(of input: String) -> String? {
        let address = input.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if let ipv4 = IPv4Address(address) {
            return ipv4.rawValue.reversed().map(String.init).joined(separator: ".") + ".in-addr.arpa"
        }
        if let ipv6 = IPv6Address(address) {
            let nibbles = ipv6.rawValue.flatMap { [$0 >> 4, $0 & 0x0F] }
            return nibbles.reversed().map { String($0, radix: 16) }.joined(separator: ".") + ".ip6.arpa"
        }
        return nil
    }

    /// The server entry for c-ares, or nil if it isn't an IP address. IPv6 addresses need square brackets and a port, c-ares rejects "[address]" alone.
    static func serverEntry(_ input: String) -> String? {
        let address = input.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if IPv4Address(address) != nil { return address }
        if IPv6Address(address) != nil { return "[\(address)]:53" }
        return nil
    }

    /// nil asks the system resolver (dnssd), otherwise c-ares asks exactly these servers.
    static func resolver(servers: [String]?) throws -> AsyncDNSResolver {
        guard let servers else { return try AsyncDNSResolver() }
        var options = CAresDNSResolver.Options.default
        options.servers = servers
        options.flags = .NOSEARCH
        options.timeoutMillis = 2000
        options.attempts = 2
        return try AsyncDNSResolver(options: options)
    }

    static func ttl(_ seconds: Int32?) -> String? {
        guard let seconds else { return nil }
        return String(format: NSLocalizedString("TTL %@", comment: "Domain Resolver: how long a record may be cached, below an address (e.g. \"TTL 5 min\")"), duration(UInt32(max(seconds, 0))))
    }

    static func duration(_ seconds: UInt32) -> String {
        Duration.seconds(Int64(seconds)).formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .abbreviated))
    }

    /// Names come back with or without the root dot depending on the resolver; show them without.
    static func clean(_ name: String) -> String {
        name.hasSuffix(".") ? String(name.dropLast()) : name
    }

    static func query(_ type: DNSRecordType, name: String, servers: [String]?) async throws -> [DNSAnswer] {
        let resolver = try resolver(servers: servers)
        do {
            switch type {
            case .a:
                return try await resolver.queryA(name: name).map { DNSAnswer(value: $0.address.address, detail: ttl($0.ttl)) }
            case .aaaa:
                return try await resolver.queryAAAA(name: name).map { DNSAnswer(value: $0.address.address, detail: ttl($0.ttl)) }
            case .cname:
                guard let cname = try await resolver.queryCNAME(name: name), !cname.isEmpty else { return [] }
                return [DNSAnswer(value: clean(cname))]
            case .mx:
                return try await resolver.queryMX(name: name)
                    .sorted { ($0.priority, $0.host) < ($1.priority, $1.host) }
                    .map { DNSAnswer(value: clean($0.host), detail: String(format: NSLocalizedString("Priority %lld", comment: "Domain Resolver: priority of a mail server, below its name (lower is tried first)"), Int($0.priority))) }
            case .txt:
                return try await resolver.queryTXT(name: name).map { DNSAnswer(value: $0.txt) }
            case .ns:
                return try await resolver.queryNS(name: name).nameservers.map(clean).sorted().map { DNSAnswer(value: $0) }
            case .soa:
                guard let soa = try await resolver.querySOA(name: name) else { return [] }
                var answers: [DNSAnswer] = []
                if let mname = soa.mname {
                    answers.append(DNSAnswer(label: NSLocalizedString("Primary Name Server", comment: "Domain Resolver: SOA record field"), value: clean(mname)))
                }
                if let rname = soa.rname {
                    // "hostmaster.example.com" stands for the mail address hostmaster@example.com
                    let mail = clean(rname).replacingOccurrences(of: ".", with: "@", options: [], range: clean(rname).range(of: "."))
                    answers.append(DNSAnswer(label: NSLocalizedString("Contact", comment: "Domain Resolver: SOA record field, the mail address of the person responsible for the domain"), value: mail))
                }
                answers.append(DNSAnswer(label: NSLocalizedString("Serial", comment: "Domain Resolver: SOA record field, the version number of the zone"), value: String(soa.serial)))
                answers.append(DNSAnswer(label: NSLocalizedString("Refresh", comment: "Domain Resolver: SOA record field, how often secondary name servers check for changes"), value: duration(soa.refresh)))
                answers.append(DNSAnswer(label: NSLocalizedString("Retry", comment: "Domain Resolver: SOA record field, how long secondary name servers wait after a failed check"), value: duration(soa.retry)))
                answers.append(DNSAnswer(label: NSLocalizedString("Expire", comment: "Domain Resolver: SOA record field, after how long secondary name servers stop answering without reaching the primary"), value: duration(soa.expire)))
                answers.append(DNSAnswer(label: NSLocalizedString("Negative Caching", comment: "Domain Resolver: SOA record field, how long the answer that a name doesn't exist may be cached"), value: duration(soa.ttl)))
                return answers
            case .ptr:
                return try await resolver.queryPTR(name: name).names.map(clean).map { DNSAnswer(value: $0) }
            }
        } catch where isNotFound(error) {
            return []
        }
    }
}

struct DomainResolver: View {
    @AppStorage("resolverResolve") var toResolve = ""
    @AppStorage("resolverServer") var server: DNSServerChoice = .system
    @AppStorage("resolverCustomServer") var customServer = ""

    @State var answers: [DNSRecordType: [DNSAnswer]] = [:]
    @State var resolving = false
    /// The lookup failed for another reason than the domain not existing (offline, timeout, …).
    @State var lookupFailed = false
    /// Changing it starts a new lookup; `.task(id:)` cancels the one still running.
    @State var resolveID = 0
    /// The text the shown result belongs to; once the user edits the domain, the old result no longer applies.
    @State var resolvedText: String? = nil

    @State var isPresentingToast: Bool = false
    @State private var network = NetworkMonitor()

    func presentToast() {
        withAnimation {
            isPresentingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isPresentingToast = false
            }
        }
    }

    /// The shown result belongs to the domain in the field.
    var isCurrent: Bool { resolvedText == toResolve }

    var hasInput: Bool { !toResolve.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The servers c-ares asks, nil for the system resolver.
    var servers: [String]? {
        switch server {
        case .system: nil
        case .custom: DNSLookup.serverEntry(customServer).map { [$0] }
        default: server.presetServers
        }
    }

    var customServerInvalid: Bool { server == .custom && servers == nil }

    func resolve() async {
        let domain = DNSLookup.host(of: toResolve)
        answers = [:]
        lookupFailed = false
        resolvedText = toResolve
        guard !domain.isEmpty, !customServerInvalid else {
            resolving = false
            return
        }
        resolving = true

        // An IP address gets a reverse lookup, a domain all the other record types
        let queries: [(DNSRecordType, String)]
        if let reverse = DNSLookup.reverseName(of: domain) {
            queries = [(.ptr, reverse)]
        } else {
            queries = DNSRecordType.forward.map { ($0, domain) }
        }

        let servers = servers
        var failures = 0
        await withTaskGroup(of: (DNSRecordType, Result<[DNSAnswer], Error>).self) { group in
            for (type, name) in queries {
                group.addTask {
                    do {
                        return (type, .success(try await DNSLookup.query(type, name: name, servers: servers)))
                    } catch {
                        return (type, .failure(error))
                    }
                }
            }
            // Show each record type as soon as it arrives
            for await (type, result) in group {
                guard !Task.isCancelled else { return }
                switch result {
                case .success(let found):
                    if !found.isEmpty { answers[type] = found }
                case .failure:
                    failures += 1
                }
            }
        }
        guard !Task.isCancelled else { return }

        lookupFailed = answers.isEmpty && failures > 0
        resolving = false
    }

    func copy(_ text: String) {
        UIPasteboard.general.string = text
        Haptic.impact(.light).generate()
        presentToast()
    }

    var body: some View {
        Form {
            if !network.isConnected {
                Section {
                    Label(NSLocalizedString("No Internet Connection", comment: "Domain Resolver: notice shown while the device is offline"), systemImage: "wifi.slash")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text(NSLocalizedString("Domains can only be resolved while you're connected to the internet.", comment: "Domain Resolver: explanation below the offline notice"))
                }
            }
            Section {
                HStack {
                    Text("Domain")
                    TextField("toolbox.sivery.de", text: $toResolve)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            resolveID += 1
                        }
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                            if let textField = obj.object as? UITextField {
                                textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                            }
                        }
                }
                Picker(NSLocalizedString("DNS Server", comment: "Domain Resolver: picker to choose which DNS server answers the lookup"), selection: $server) {
                    ForEach(DNSServerChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                if server == .custom {
                    HStack {
                        Text(NSLocalizedString("Server Address", comment: "Domain Resolver: label of the field for the IP address of a custom DNS server"))
                        TextField("192.168.1.1", text: $customServer)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.go)
                            .onSubmit {
                                resolveID += 1
                            }
                    }
                }
            } footer: {
                if customServerInvalid && !customServer.isEmpty {
                    Text(NSLocalizedString("Enter the IPv4 or IPv6 address of a DNS server.", comment: "Domain Resolver: shown below the custom DNS server field when it holds no valid IP address"))
                } else {
                    Text(NSLocalizedString("Enter a domain, or an IP address to find its host name.", comment: "Domain Resolver: explanation below the domain field"))
                }
            }

            if isCurrent && hasInput {
                if !answers.isEmpty {
                    ForEach(DNSRecordType.allCases.filter { answers[$0] != nil }) { type in
                        Section(type.title) {
                            ForEach(answers[type] ?? []) { answer in
                                answerRow(answer)
                            }
                        }
                    }
                }
                if resolving {
                    Section {
                        HStack {
                            Text(NSLocalizedString("Looking up…", comment: "Domain Resolver: shown while the DNS lookup is running"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            ProgressView()
                        }
                    }
                } else if lookupFailed {
                    Section {
                        Text(NSLocalizedString("Lookup Failed", comment: "Domain Resolver: result shown when the DNS lookup failed for another reason than the domain not existing (offline, timeout)"))
                    } footer: {
                        Text(NSLocalizedString("The DNS server couldn't be reached. Check your internet connection and try again.", comment: "Domain Resolver: explanation below the result when the DNS lookup failed"))
                    }
                } else if answers.isEmpty && !customServerInvalid {
                    Section {
                        Text(NSLocalizedString("Not Found", comment: "Domain Resolver: result shown when the domain has no DNS records"))
                    }
                }
            }
        }
        .animation(.default, value: network.isConnected)
        .animation(.default, value: answers)
        .animation(.default, value: server)
        .onChange(of: network.isConnected) { _, isConnected in
            if isConnected {
                resolveID += 1
            }
        }
        .onChange(of: server) {
            resolveID += 1
        }
        // Runs on appear and whenever resolveID changes, cancelling the previous lookup
        .task(id: resolveID) {
            await resolve()
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Domain Resolver")
    }

    /// Tapping a line copies its value.
    func answerRow(_ answer: DNSAnswer) -> some View {
        Button {
            copy(answer.value)
        } label: {
            if let label = answer.label {
                LabeledContent(label) {
                    Text(answer.value)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(answer.value)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let detail = answer.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(.primary)
    }
}

#Preview {
    NavigationStack {
        DomainResolver()
    }
}
