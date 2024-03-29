//
//  InfoView.swift
//  Toolbox
//
//  Created by Christian Nagel on 05.11.22.
//

import Foundation
import SwiftUI
import CoreData


struct infoView: View {
    
    @Environment(\.showingSheet) var showingSheet
    @Environment(\.managedObjectContext) var managedContext
    @State var deleteAlert = false
    
    var body: some View {
        List {
            Section {
                NavigationLink(destination: infoVersion()){
                    Label("Version", systemImage: "info")
                }
                
                NavigationLink(destination: appIcon().environmentObject(IconNames())) {
                    Label("App Icon", systemImage: "square")
                }
                
                NavigationLink(destination: permissions()){
                    Label("Permissions", systemImage: "shield")
                }
                
                Button(action: {
                    if let url = URL(string: "http://toolbox.sivery.de") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Website", systemImage: "globe")
                }
                .tint(.primary)
                
                Button(action: {
                    if let url = URL(string: "mailto:toolbox@sivery.de") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Feedback", systemImage: "mail")
                }
                .tint(.primary)
                
                Button(action: {
                    if let url = URL(string: "https://itunes.apple.com/app/id1638758005?action=write-review") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Rate app", systemImage: "star")
                }
                .tint(.primary)
                
                Button(action: {
                    if let url = URL(string: "http://mailing.sivery.de/subscription/form") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Mailing list", systemImage: "mail.stack")
                }
                .tint(.primary)
                
                
                Button(action: {
                    shareFromSheet(shareItem: [URL(string: "http://toolbox.sivery.de/download")!])
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.primary)
                
                Button(action: {
                    if let url = URL(string: "http://toolbox.sivery.de/support") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Support the development", systemImage: "heart")
                }
                .tint(.primary)
                
                
                
                Button(action: {
                    deleteAlert = true
                }) {
                    Label("Delete data", systemImage: "trash")
                }
                .tint(.primary)
                
                
            }
            
            
            Section{
                
                Button(action: {
                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                    }
                }) {
                    Label("OpenSource-Licenses", systemImage: "checkmark.seal")
                }
                .tint(.primary)
                
                
                Button(action: {
                    if let privacy = URL(string: "http://toolbox.sivery.de/privacy.html") {
                        UIApplication.shared.open(privacy, options: [:], completionHandler: nil)
                    }
                }) {
                    Label("Privacy Policy", systemImage: "lock")
                }
                .tint(.primary)
                
                Button(action: {
                    if let privacy = URL(string: "http://toolbox.sivery.de/contribution.html") {
                        UIApplication.shared.open(privacy, options: [:], completionHandler: nil)
                    }
                }) {
                    Label("Contribute", systemImage: "person.3")
                }
                .tint(.primary)
                
                
            }
            
            Section {
                HStack {
                    Spacer()
                    Text("Made with ❤️ by Sivery")
                    Spacer()
                }
            }
            
        }
        .alert(isPresented: $deleteAlert){
            Alert(title: Text("Are you sure, you want to clear the app's data?"),
                  message: Text("The app will close after deleting the data. You can instantly reopen it."),
                  primaryButton: .cancel(),
                  secondaryButton: .destructive(Text("Delete")) {
                let domain = Bundle.main.bundleIdentifier!
                UserDefaults.standard.removePersistentDomain(forName: domain)
                UserDefaults.standard.synchronize()
                print(Array(UserDefaults.standard.dictionaryRepresentation().keys).count)
                SBDataController().resetBarcodes(context: managedContext)
                UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
                exit(-1)
            }
            )
        }
        .navigationBarTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarItems(trailing:
                                Button("Done") {
            self.showingSheet?.wrappedValue = false
        }
        )
    }
}

struct infoVersion: View {
    var body: some View  {
        List{
            Section{
                HStack{
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Can't find version")
                }
                HStack{
                    Text("Last updated")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["LAST_UPDATE"] as? String ?? "Can't find last update")
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Can't find build")
                }
                
            }
            Section {
                Button("Open AppStore", action: {
                    if let url = URL(string: "https://itunes.apple.com/app/id1638758005") {
                        UIApplication.shared.open(url)
                    }
                })
            }
            //            Text("No update available") TODO: use this with https://github.com/acarolsf/checkVersion-iOS when published
        }
        
        .navigationTitle("Version")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct appIcon: View {
    @EnvironmentObject var iconSettings:IconNames
    
    var body: some View {
        Form {
            
            LazyVGrid(columns: [GridItem(), GridItem()]) {
                
                ForEach(0 ..< iconSettings.iconNames.count, id: \.self){i in
                    
                    Image(uiImage: i == 0 ? UIImage(named: "ToolboxRAW")! : UIImage(named: self.iconSettings.iconNames[i] ?? "ToolboxRAW") ?? UIImage())
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .aspectRatio(CGSize(width: 100, height: 100), contentMode: .fit)
                        .cornerRadius(20)
                        .clipped()
                        .onTapGesture(){
                            
                            if iconSettings.currentIndex != i {
                                print(self.iconSettings.iconNames)
                                
                                UIApplication.shared.setAlternateIconName(self.iconSettings.iconNames[i], completionHandler: {
                                    error in
                                    if let error = error {
                                        print(error.localizedDescription)
                                    } else {
                                        print("Success!")
                                        iconSettings.currentIndex = i
                                    }
                                })
                            }
                        }
                }
            }
            
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct permissions: View {
    
    @StateObject var locationManager = Location_helper()
    @State var localNetworkAccess:Bool? = nil
    
    @State var showingInfoAlert = false
    
    var body: some View {
        List {
            HStack {
                Label("Location", systemImage: "location.fill")
                Spacer()
                if (locationManager.locationStatus == .authorizedAlways) {
                    Text("Always")
                }
                if (locationManager.locationStatus == .authorizedWhenInUse) {
                    Text("While Using")
                }
                if (locationManager.locationStatus == .denied) {
                    Text("Denied")
                }
                if (locationManager.locationStatus == .restricted) {
                    Text("restricted")
                }
                if (locationManager.locationStatus == .notDetermined) {
                    Text("Not Determined")
                }
                if (locationManager.locationStatus == .none) {
                    Text("None")
                }
            }
            
            HStack {
                Label("Local Network", systemImage: "network")
                Spacer()
                if (localNetworkAccess == true) {
                    Text("Allowed")
                }
                if (localNetworkAccess == false) {
                    Text("Denied")
                }
                if (localNetworkAccess == nil) {
                    Text("")
                }
            }
            
            Section{
                Button("Open Settings") {
                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                    }
                }
            }
        }
        .onAppear {
            checkNetworkPermission()
        }
        .alert(isPresented: $showingInfoAlert) {
            Alert(
                title: Text("Why?"),
                message: Text("Toolbox uses your location to calculate your speed and your coordinates when using the corresponding tools.\n Toolbox needs access to your local network when using the LAN Scanner."),
                dismissButton: .destructive(Text("Got it!")) // I have to use .destructive and not .default, because .default often times is the default primary blue and not the color set in Assets AccentColor
            )
                }
        .toolbar(){
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingInfoAlert = true
                }, label: {
                    Image(systemName: "questionmark.circle")
                })
            }
        }
        
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func checkNetworkPermission() {
            let authorization = LocalNetworkAuthorization()
            authorization.requestAuthorization { hasPermission in
                DispatchQueue.main.async {
                    self.localNetworkAccess = hasPermission
                }
            }
        }
}

struct permissions_Previews: PreviewProvider {
    static var previews: some View {
        permissions()
    }
}
