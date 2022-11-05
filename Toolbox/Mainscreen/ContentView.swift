//
//  ContentView.swift
//  Toolbox
//
//  Created by Christian Nagel on 08.03.22.
//

import SwiftUI
import StoreKit

extension UIApplication {
    
    static let keyWindow = keyWindowScene?.windows.filter(\.isKeyWindow).first
    static let keyWindowScene = shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
    
}
enum Coordinator {
    static func topViewController(_ viewController: UIViewController? = nil) -> UIViewController? {
        let vc = viewController ?? UIApplication.shared.currentUIWindow()?.rootViewController
        if let navigationController = vc as? UINavigationController {
            return topViewController(navigationController.topViewController)
        } else if let tabBarController = vc as? UITabBarController {
            return tabBarController.presentedViewController != nil ? topViewController(tabBarController.presentedViewController) : topViewController(tabBarController.selectedViewController)
            
        } else if let presentedViewController = vc?.presentedViewController {
            return topViewController(presentedViewController)
        }
        return vc
    }
}

public extension UIApplication {
    func currentUIWindow() -> UIWindow? {
        let connectedScenes = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
        
        let window = connectedScenes.first?
            .windows
            .first { $0.isKeyWindow }
        
        return window
        
    }
}

extension View {
    
    func shareFromSheet(shareItem: [Any]) {
        
        let activityViewController = UIActivityViewController(activityItems: shareItem, applicationActivities: nil)
        
        let viewController = Coordinator.topViewController()
        activityViewController.popoverPresentationController?.sourceView = viewController?.view
        viewController?.present(activityViewController, animated: true, completion: nil)
    }
    
    func shareFromView(shareItem: [Any]) {
        let shareActivity = UIActivityViewController(activityItems: shareItem, applicationActivities: nil)
        if let vc = UIApplication.shared.currentUIWindow()?.rootViewController{
            shareActivity.popoverPresentationController?.sourceView = vc.view
            //Setup share activity position on screen on bottom center
            shareActivity.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height, width: 0, height: 0)
            shareActivity.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.down
            vc.present(shareActivity, animated: true, completion: nil)
        }
    }
    
    
}

struct ShowingSheetKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

extension EnvironmentValues {
    var showingSheet: Binding<Bool>? {
        get { self[ShowingSheetKey.self] }
        set { self[ShowingSheetKey.self] = newValue }
    }
}

struct ContentView: View {
    
    @State var infoPresented = false
    @AppStorage("cvLoaded") var viewLoaded = 0
    
    let tools = [
        [
            "view": "dice",
            "icon": "dice",
            "title": NSLocalizedString("Dice", comment: "Menu item")
        ],
        [
            "view": "domain",
            "icon": "network",
            "title": NSLocalizedString("Domain Resolver", comment: "Menu item")
        ],
        [
            "view": "randomNumber",
            "icon": "number",
            "title": NSLocalizedString("Random Number", comment: "Menu item")
        ],
        [
            "view": "liveClock",
            "icon": "clock",
            "title": NSLocalizedString("Live Clock", comment: "Menu item")
        ],
        [
            "view": "dateDifferene",
            "icon": "calendar",
            "title": NSLocalizedString("Date Difference", comment: "Menu item")
        ],
        [
            "view": "romanNumbers",
            "icon": "hexagon",
            "title": NSLocalizedString("Roman Numbers", comment: "Menu item")
        ],
        [
            "view": "counter",
            "icon": "plusminus",
            "title": NSLocalizedString("Counter", comment: "Menu item")
        ],
        [
            "view": "qrCode",
            "icon": "qrcode",
            "title": NSLocalizedString("QR-Code Generator", comment: "Menu item")
        ],
        [
            "view": "colorPicker",
            "icon": "eyedropper.halffull",
            "title": NSLocalizedString("Color Picker", comment: "Menu item")
        ],
        [
            "view": "BodyMassIndex",
            "icon": "person.fill.checkmark",
            "title": NSLocalizedString("BMI", comment: "Menu item")
        ],
        [
            "view": "ipChecker",
            "icon": "ellipsis.rectangle",
            "title": NSLocalizedString("IP-Checker", comment: "Menu item")
        ],
        [
            "view": "ping",
            "icon": "bolt.horizontal",
            "title": NSLocalizedString("Ping", comment: "Menu item")
        ],
        [
            "view": "coords",
            "icon": "location",
            "title": NSLocalizedString("Coordinates", comment: "Menu item")
        ],
        [
            "view": "speed",
            "icon": "speedometer",
            "title": NSLocalizedString("Speed", comment: "Menu item")
        ],
        //        eventually in Future Version
//                [
//                    "view": "nfc",
//                    "icon": "wave.3.forward",
//                    "title": "NFC Editor"
//                ]
        //        [
        //            "view": "unit",
        //            "icon": "ruler",
        //            "title": "Unit Conversion"
        //        ]
    ]
    
    var body: some View {
        NavigationView {
            List {
                
                ForEach(tools, id: \.self) { tool in
                    NavigationLink {
                        switch tool["view"]{
                        case "dice":
                            DiceView()
                        case "domain":
                            DomainResolver()
                        case "randomNumber":
                            RandomNumber()
                        case "liveClock":
                            LiveClock()
                        case "dateDifferene":
                            DateDifference()
                        case "romanNumbers":
                            RomanConverter()
                        case "counter":
                            Counter()
                        case "qrCode":
                            QRGenerator()
                        case "colorPicker":
                            ColorPickerView()
                        case "BodyMassIndex":
                            BodyMassIndex()
                        case "ipChecker":
                            ipChecker()
                        case "ping":
                            Ping()
                        case "coords":
                            Coordinates()
                        case "speed":
                            Speed ()
//                        case "nfc":
//                            nfc()
                        default:
                            Text("ERROR - Tool not found!\nPlease report this bug.")
                        }
                    } label: {
                        Label("\(tool["title"]!)", systemImage: "\(tool["icon"]!)").foregroundColor(.primary)
                    }
                    
                    
                    
                }
            }
            .sheet(isPresented: $infoPresented){
                NavigationView{
                    infoView()
                        .environment(\.showingSheet, self.$infoPresented)
                }
                
            }
            .navigationTitle("Toolbox")
            .toolbar(){
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        infoPresented = true
                    }, label: {
                        Image(systemName: "info.circle")
                    })
                }
            }
            Text("Select a tool")
        }.onAppear() {
            viewLoaded += 1
            if (viewLoaded == 50) {
                guard let currentScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    print("UNABLE TO GET CURRENT SCENE")
                    return
                }
                SKStoreReviewController.requestReview(in: currentScene)
            }else if (viewLoaded == 150) {
                guard let currentScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    print("UNABLE TO GET CURRENT SCENE")
                    return
                }
                SKStoreReviewController.requestReview(in: currentScene)
            }else if (viewLoaded == 400) {
                guard let currentScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    print("UNABLE TO GET CURRENT SCENE")
                    return
                }
                SKStoreReviewController.requestReview(in: currentScene)
            }
        }
    }
        
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        infoView().previewDevice("iPhone 13").environmentObject(IconNames())
    }
}




struct infoView: View {
    
    
    
    @Environment(\.showingSheet) var showingSheet
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
            
            // TODO: After AppStore Enrollment:
            //            NavigationLink(destination: info()){
            //                Label("Spenden", systemImage: "suit.heart") //Localization europe: eurosign.circle
            //            }
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
                Label("Rate App", systemImage: "star")
            }
            .tint(.primary)
            
            Button(action: {
                if let url = URL(string: "http://mailing.sivery.de/subscription/form") {
                    UIApplication.shared.open(url)
                }
            }) {
                Label("Mailing-List", systemImage: "mail.stack")
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
                Label("Delete Data", systemImage: "trash")
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
                      
                      primaryButton: .cancel(),
                      secondaryButton: .destructive(Text("Delete")) {
                    let domain = Bundle.main.bundleIdentifier!
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    UserDefaults.standard.synchronize()
                    print(Array(UserDefaults.standard.dictionaryRepresentation().keys).count)
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
                    Text("Last update")
                    Spacer()
                    Text("1-09-2022")
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
    }
}

