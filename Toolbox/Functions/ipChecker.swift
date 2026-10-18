//
//  ipChecker.swift
//  Toolbox
//
//  Created by Christian Nagel on 29.08.22.
//

import SwiftUI
import ToastSwiftUI
import Haptica

/// Asks checkip.amazonaws.com for the public IP address. Returns nil when it can't be reached
/// or doesn't answer with an IP address.
func checkIP() async -> String? {
    guard let url = URL(string: "https://checkip.amazonaws.com") else { return nil }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
    request.httpMethod = "GET"
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let contents = String(data: data, encoding: .utf8) else { return nil }
        let ip = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        return isIPAddress(ip) ? ip : nil
    } catch {
        return nil
    }
}

/// Whether the string is a valid IPv4 or IPv6 address.
func isIPAddress(_ string: String) -> Bool {
    var ipv4 = in_addr()
    var ipv6 = in6_addr()
    return inet_pton(AF_INET, string, &ipv4) == 1 || inet_pton(AF_INET6, string, &ipv6) == 1
}


struct ipChecker: View {
    /// The last IP address found, empty if there is none.
    @AppStorage("ipIP") var ip: String = ""
    @State var checking = false
    @State var isPresentingToast: Bool = false
    
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
    
    func check() async {
        guard !checking else { return }
        checking = true
        ip = await checkIP() ?? ""
        checking = false
    }
    
    /// Older versions stored the localized "Not found" text instead of an address.
    var hasIP: Bool { isIPAddress(ip) }
    
    var body: some View {
        
        Form {
            Button(action: {
                guard hasIP, !checking else { return }
                UIPasteboard.general.string = ip
                Haptic.impact(.light).generate()
                presentToast()
            }) {
                HStack{
                    Text("Your current IP")
                    Spacer()
                    if checking {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text(hasIP ? ip : NSLocalizedString("Not found", comment: "IP-Checker: shown instead of the public IP address when it couldn't be loaded"))
                    }
                }
                .tint(.primary)
            }
            
            Button("Check Again") {
                Task {
                    await check()
                }
            }
            .disabled(checking)
        }
        .task {
            await check()
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("IP-Checker")
    }
       
}


struct ipChecker_Previews: PreviewProvider {
    static var previews: some View {
        ipChecker()
    }
}
