//
//  DomainResolver.swift
//  Toolbox
//
//  Created by Christian Nagel on 17.03.22.
//

import SwiftUI
import Haptica
import ToastSwiftUI
import AsyncDNSResolver

struct DomainResolver: View {
    @AppStorage("resolverResolve") var toResolve = ""
    @State var addresses: [String] = []
    @State var resolving = false
    /// The lookup failed for another reason than the domain not existing (offline, timeout, …).
    @State var lookupFailed = false
    /// Changing it starts a new lookup; `.task(id:)` cancels the one still running.
    @State var resolveID = 0
    
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
    
    /// "No such name" / "no such record" from dnssd – the domain has no address of that type.
    static func isNotFound(_ error: Error) -> Bool {
        let code = ((error as? AsyncDNSResolver.Error)?.source as? DNSSDError)?.code
        return code == -65538 /* kDNSServiceErr_NoSuchName */ || code == -65554 /* kDNSServiceErr_NoSuchRecord */
    }
    
    static func lookup(_ query: () async throws -> [String]) async -> Result<[String], Error> {
        do {
            return .success(try await query())
        } catch {
            return isNotFound(error) ? .success([]) : .failure(error)
        }
    }
    
    func resolve() async {
        let domain = toResolve.trimmingCharacters(in: .whitespacesAndNewlines)
        addresses = []
        lookupFailed = false
        guard !domain.isEmpty else {
            resolving = false
            return
        }
        resolving = true
        
        async let ipv4 = DomainResolver.lookup { try await AsyncDNSResolver().queryA(name: domain).map { $0.address.address } }
        async let ipv6 = DomainResolver.lookup { try await AsyncDNSResolver().queryAAAA(name: domain).map { $0.address.address } }
        
        // IPv4 usually answers first, so show it while IPv6 is still on its way
        let ipv4Result = await ipv4
        guard !Task.isCancelled else { return }
        let ipv4Addresses = (try? ipv4Result.get()) ?? []
        addresses = ipv4Addresses
        
        let ipv6Result = await ipv6
        guard !Task.isCancelled else { return }
        let ipv6Addresses = (try? ipv6Result.get()) ?? []
        let found = ipv4Addresses + ipv6Addresses
        
        var failed = false
        if found.isEmpty, case .failure = ipv4Result { failed = true }
        if found.isEmpty, case .failure = ipv6Result { failed = true }
        
        addresses = found
        lookupFailed = failed
        resolving = false
    }
    
    var body: some View {
        Form{
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
                .keyboardType(/*@START_MENU_TOKEN@*/.URL/*@END_MENU_TOKEN@*/)
                .textCase(/*@START_MENU_TOKEN@*/.lowercase/*@END_MENU_TOKEN@*/)
                .textContentType(/*@START_MENU_TOKEN@*/.URL/*@END_MENU_TOKEN@*/)
                .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
                .multilineTextAlignment(.trailing)
                .onSubmit(of: /*@START_MENU_TOKEN@*/.text/*@END_MENU_TOKEN@*/) {
                    resolveID += 1
                }
                .disableAutocorrection(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
            .submitLabel(.go)
                .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                    if let textField = obj.object as? UITextField {
                        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                    }
                }
            }
            HStack {
                Text("Result")
                Spacer()
                Button(action: {
                    if !addresses.isEmpty {
                        UIPasteboard.general.string = addresses.joined(separator: "\n")
                        Haptic.impact(.light).generate()
                        presentToast()
                    }
                }) {
                    HStack {
                        if resolving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        if !addresses.isEmpty {
                            Text(addresses.joined(separator: "\n"))
                                .multilineTextAlignment(.trailing)
                        } else if lookupFailed {
                            Text(NSLocalizedString("Lookup Failed", comment: "Domain Resolver: result shown when the DNS lookup failed for another reason than the domain not existing (offline, timeout)"))
                        } else if !resolving && !toResolve.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(NSLocalizedString("Not Found", comment: "Domain Resolver: result shown when the domain has no IPv4 or IPv6 address"))
                        }
                    }
                }
                .tint(.primary)
            }
            } footer: {
                if lookupFailed {
                    Text(NSLocalizedString("The DNS server couldn't be reached. Check your internet connection and try again.", comment: "Domain Resolver: explanation below the result when the DNS lookup failed"))
                }
            }
        }
        .animation(.default, value: network.isConnected)
        .onChange(of: network.isConnected) { _, isConnected in
            if isConnected {
                resolveID += 1
            }
        }
        // Runs on appear and whenever resolveID changes, cancelling the previous lookup
        .task(id: resolveID) {
            await resolve()
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Domain Resolver")
    }
}

struct DomainResolver_Previews: PreviewProvider {
    static var previews: some View {
        DomainResolver()
    }
}

