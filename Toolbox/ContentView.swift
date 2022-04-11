//
//  ContentView.swift
//  Toolbox
//
//  Created by Christian Nagel on 08.03.22.
//

import SwiftUI
import RomanNumeralKit

struct ContentView: View {
    
    @State var infoPresented = false
    
    let tools = [
        [
            "view": "dice",
            "icon": "dice",
            "title": "Dice"
        ],
        [
            "view": "domain",
            "icon": "network",
            "title": "Domain Resolver"
        ],
        [
            "view": "randomNumber",
            "icon": "textformat.123",
            "title": "Random Number"
        ],
        [
            "view": "liveClock",
            "icon": "clock",
            "title": "Live Clock"
        ],
        [
            "view": "dateDifferene",
            "icon": "calendar",
            "title": "Date Difference"
        ],
        [
            "view": "romanNumbers",
            "icon": "hexagon",
            "title": "Roman Numbers"
        ],
        [
            "view": "counter",
            "icon": "plusminus",
            "title": "Counter"
        ],
        [
            "view": "qrCode",
            "icon": "qrcode",
            "title": "QR-Code Generator"
        ],
        [
            "view": "colorPicker",
            "icon": "eyedropper.halffull",
            "title": "Color Picker"
        ],
        [
            "view": "bmi",
            "icon": "person.fill.checkmark",
            "title": "BMI"
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
                InfoView()
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
        ContentView().previewDevice("iPhone 13").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}


struct InfoView: View {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    var body: some View {
        VStack {
            Spacer()
            Image("Toolbox")
            Text("Toolbox")
                .bold()
                .dynamicTypeSize(.accessibility2)
            
            Text("Version " + (appVersion ?? "not found"))
            Spacer()
            Button("Report Bug") {
                UIApplication.shared.open(URL(string: "mailto:toolbox@sivery.de?subject=I%20found%20a%20Bug!&body=Please%20give%20a%20brief%20description%20of%20the%20bug%20and%20how%20to%20reproduce%20it!")!, options: [:])
            }

            Spacer()
            Text("Made with ❤️ by Sivery")
                .onTapGesture {
                    UIApplication.shared.open(URL(string: "https://sivery.de")!, options: [:])
                }

            Text("OpenSource Licenses")
                .onTapGesture {
                    UIApplication.shared.open(URL(string: "https://toolbox.sivery.de/licenses.txt")!, options: [:])
                }
            
            Text("Icon by icons8.com")
                .padding(.bottom)
                .onTapGesture {
                    UIApplication.shared.open(URL(string: "https://icons8.com")!, options: [:])
                }


        }
        
    }
}
