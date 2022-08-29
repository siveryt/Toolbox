//
//  DomainResolver.swift
//  Toolbox
//
//  Created by Christian Nagel on 17.03.22.
//

import SwiftUI
import Haptica
import ToastSwiftUI

struct DomainResolver: View {
    @AppStorage("resolverResolve") var toResolve = ""
    @State var resolved = ""
    @State var autoResolve = true
    
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
    
    func resolve() {
        if(toResolve != ""){
            let host = CFHostCreateWithName(nil,toResolve as CFString).takeRetainedValue()
            CFHostStartInfoResolution(host, .addresses, nil)
            var success: DarwinBoolean = false
            if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
               let theAddress = addresses.firstObject as? NSData {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let numAddress = String(cString: hostname)
                    resolved = numAddress
                }
            }
        }
    }
    
    var body: some View {
        Form{
//            Section(header: Text(" ")){
            HStack {
                Text("Domain")
                TextField("toolbox.sivery.de", text: $toResolve)
                .keyboardType(/*@START_MENU_TOKEN@*/.URL/*@END_MENU_TOKEN@*/)
                .textCase(/*@START_MENU_TOKEN@*/.lowercase/*@END_MENU_TOKEN@*/)
                .textContentType(/*@START_MENU_TOKEN@*/.URL/*@END_MENU_TOKEN@*/)
                .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
                .multilineTextAlignment(.trailing)
                .onSubmit(of: /*@START_MENU_TOKEN@*/.text/*@END_MENU_TOKEN@*/) {
                    resolve()
                }
                .disableAutocorrection(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
            .submitLabel(.go)
            }
            HStack {
                Text("Result")
                Spacer()
                Button(action: {
                    if(resolved != ""){
                        UIPasteboard.general.string = resolved
                        Haptic.impact(.light).generate()
                        presentToast()
                    }
                }) {
                    Text(resolved == "" ? NSLocalizedString("Not Found", comment: "Domain Not found") : resolved)
                        .multilineTextAlignment(.trailing)
                        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                            if let textField = obj.object as? UITextField {
                                textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                            }
                        }
                        
                        
                }
                .tint(.primary)
            }
            
            
//            }
            
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

