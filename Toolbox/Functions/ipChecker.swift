//
//  ipChecker.swift
//  Toolbox
//
//  Created by Christian Nagel on 29.08.22.
//

import SwiftUI
import ToastSwiftUI
import Haptica

func checkIP() async -> String {
    if let url = URL(string: "https://checkip.amazonaws.com") {
        do {
            let contents = try String(contentsOf: url)
            return contents.replacingOccurrences(of: "\n", with: "")
        } catch {
            return NSLocalizedString("Not found", comment: "IP-Checker not found")
        }
    } else {
        return NSLocalizedString("Not found", comment: "IP-Checker not found")
    }
}


struct ipChecker: View {
    @AppStorage("ipIP") var ip:String = NSLocalizedString("Not found", comment: "IP-Checker not found")
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
    
    var body: some View {
        
        Form {
            Button(action: {
                UIPasteboard.general.string = ip
                Haptic.impact(.light).generate()
                presentToast()
            }) {
                HStack{
                    Text("Your current IP")
                    Spacer()
                    Text(ip)
                }
                .tint(.primary)
            }
            
            Button("Check Again") {
                Task {
                    ip = await checkIP()
                    
                }
            }
        }
        .onAppear() {
            Task {
                ip = await checkIP()
                
            }
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
