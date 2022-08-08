//
//  ContentView.swift
//  Toolbox
//
//  Created by Christian Nagel on 08.03.22.
//

import SwiftUI
import RomanNumeralKit

extension UIApplication {
    
    static let keyWindow = keyWindowScene?.windows.filter(\.isKeyWindow).first
    static let keyWindowScene = shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
    
}

extension View {
    
    func shareSheet(isPresented: Binding<Bool>, items: [Any]) -> some View {
        guard isPresented.wrappedValue else { return self }
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let presentedViewController = UIApplication.keyWindow?.rootViewController?.presentedViewController ?? UIApplication.keyWindow?.rootViewController
        activityViewController.completionWithItemsHandler = { _, _, _, _ in isPresented.wrappedValue = false }
        presentedViewController?.present(activityViewController, animated: true)
        return self
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
            "icon": "textformat.123",
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
            "view": "bmi",
            "icon": "person.fill.checkmark",
            "title": NSLocalizedString("BMI", comment: "Menu item")
        ]
        //        Future Version
        //        [
        //            "view": "nfcTools",
        //            "icon": "wave.3.forward",
        //            "title": "NFC Tools"
        //        ],
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
                        case "bmi":
                            BodyMassIndex()
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
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        infoView().previewDevice("iPhone 13").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext).environmentObject(IconNames())
    }
}

struct infoView: View {
    @Environment(\.showingSheet) var showingSheet
    @State private var isPresentingShareSheet = false
    var body: some View {
            List {
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
                
                Label("Website", systemImage: "globe")
                    .onTapGesture {
                        if let url = URL(string: "http://toolbox.sivery.de") {
                            UIApplication.shared.open(url)
                        }
                    }
                
                Label("Feedback", systemImage: "mail")
                    .onTapGesture {
                        if let url = URL(string: "mailto:toolbox@sivery.de") {
                            UIApplication.shared.open(url)
                        }
                    }
                
                Label("Share", systemImage: "square.and.arrow.up")
                    .onTapGesture {
                        isPresentingShareSheet = true
                    }
                    .shareSheet(isPresented: $isPresentingShareSheet, items: [URL(string: "http://toolbox.sivery.de")!])
                
                //            NavigationLink(destination: info()){
                Label("OpenSource-Licenses", systemImage: "checkmark.seal")
                    .onTapGesture {
                        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                        }
                    }
                Label("Imprint", systemImage: "doc.append")
                    .onTapGesture {
                        if let appSettings = URL(string: "http://toolbox.sivery.de/imprint.html") {
                            UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                        }
                    }
                HStack {
                    Spacer()
                    Text("Made with ❤️ by Sivery")
                    Spacer()
                }
                
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
                    Text("08-08-2022")
                }
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

