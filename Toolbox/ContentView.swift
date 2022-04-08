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
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink {
                    DiceView()
                } label: {
                    Label("Dice", systemImage: "dice").foregroundColor(.primary)
                }
                NavigationLink {
                    DomainResolver()
                } label: {
                    Label("Domain Resolver", systemImage: "network").foregroundColor(.primary)
                }
                NavigationLink {
                    RandomNumber()
                } label: {
                    Label("Random Number", systemImage: "textformat.123").foregroundColor(.primary)
                }
                NavigationLink {
                    LiveClock()
                } label: {
                    Label("Live Clock", systemImage: "clock").foregroundColor(.primary)
                }
                NavigationLink {
                    DateDifference()
                } label: {
                    Label("Date Difference", systemImage: "calendar").foregroundColor(.primary)
                }
                NavigationLink {
                    RomanConverter()
                } label: {
                    Label("Roman Numbers", systemImage: "hexagon").foregroundColor(.primary)
                }
                NavigationLink {
                    Counter()
                } label: {
                    Label("Counter", systemImage: "plusminus").foregroundColor(.primary)
                }
                NavigationLink {
                    QRGenerator()
                } label: {
                    Label("QR-Code Generator", systemImage: "qrcode").foregroundColor(.primary)
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
