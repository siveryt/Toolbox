//
//  ContentView.swift
//  Toolbox
//
//  Created by Christian Nagel on 08.03.22.
//

import SwiftUI
import StoreKit
import WhatsNewKit

struct Tool: Identifiable {
    var id = UUID()
    
    let view: AnyView
    let title: String
    let icon: String
    
    
}

struct ContentView: View {
    
    @State var infoPresented = false
    @AppStorage("cvLoaded") var viewLoaded = 0
    @AppStorage("cvOrder") var order = [0]
    
    
    @State var toollist:[Tool] = [
        Tool(view: AnyView(DiceView()), title: NSLocalizedString("Dice", comment: "Menu item"), icon: "dice"),
        Tool(view: AnyView(DomainResolver()), title: NSLocalizedString("Domain Resolver", comment: "Menu item"), icon: "network"),
        Tool(view: AnyView(RandomNumber()), title: NSLocalizedString("Random Number", comment: "Menu item"), icon: "number"),
        Tool(view: AnyView(Random_Letter()), title: NSLocalizedString("Random Letter", comment: "Menu item"), icon: "character"),
        Tool(view: AnyView(LiveClock()), title: NSLocalizedString("Live Clock", comment: "Menu item"), icon: "clock"),
        Tool(view: AnyView(DateDifference()), title: NSLocalizedString("Date Difference", comment: "Menu item"), icon: "calendar"),
        Tool(view: AnyView(RomanConverter()), title: NSLocalizedString("Roman Numbers", comment: "Menu item"), icon: "hexagon"),
        Tool(view: AnyView(Counter()), title: NSLocalizedString("Counter", comment: "Menu item"), icon: "plusminus"),
        Tool(view: AnyView(QRGenerator()), title: NSLocalizedString("QR-Code Generator", comment: "Menu item"), icon: "qrcode"),
        Tool(view: AnyView(ColorPickerView()), title: NSLocalizedString("Color Picker", comment: "Menu item"), icon: "eyedropper.halffull"),
        Tool(view: AnyView(BodyMassIndex()), title: NSLocalizedString("BMI", comment: "Menu item"), icon: "person.fill.checkmark"),
        Tool(view: AnyView(ipChecker()), title: NSLocalizedString("IP-Checker", comment: "Menu item"), icon: "ellipsis.rectangle"),
        Tool(view: AnyView(LAN_Scanner()), title: NSLocalizedString("LAN Scanner", comment: "Menu item"), icon: "magnifyingglass"),
        Tool(view: AnyView(Ping()), title: NSLocalizedString("Ping", comment: "Menu item"), icon: "bolt.horizontal"),
        Tool(view: AnyView(Coordinates()), title: NSLocalizedString("Coordinates", comment: "Menu item"), icon: "location"),
        Tool(view: AnyView(Speed()), title: NSLocalizedString("Speed", comment: "Menu item"), icon: "speedometer"),
        Tool(view: AnyView(Barcode()), title: NSLocalizedString("Barcode Scanner", comment: "Menu item"), icon: "barcode"),
        Tool(view: AnyView(PulsingFlashlight()), title: NSLocalizedString("Pulsing Flashlight", comment: "Menu item"), icon: "flashlight.off.fill"),
        
        
        
    ]
    @State private var tools:[Tool] = []
    
    
    private func onMove(source: IndexSet, destination: Int) {
            tools.move(fromOffsets: source, toOffset: destination)
        order.move(fromOffsets: source, toOffset: destination)
        }
    
    var body: some View {
        NavigationView {
            List() {
                
                ForEach(tools) { tool in
                    NavigationLink(destination: tool.view) {
                        Label(tool.title, systemImage: tool.icon).foregroundColor(.primary)
                    }
                    
                }
                .onMove(perform: onMove)
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
            
            if(order.count != toollist.count) {
                order = []
                for i in order.count..<(toollist.count-order.count) {
                    order.append(i)
                }
            }
            
            for i in order {
                tools.append(toollist[i])
            }
            
            viewLoaded += 1
            print("App Started \(viewLoaded) times")
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
            }else if (viewLoaded == 300) {
                guard let currentScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    print("UNABLE TO GET CURRENT SCENE")
                    return
                }
                SKStoreReviewController.requestReview(in: currentScene)
            }
        }
        .whatsNewSheet()
    }
    
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        infoView().previewDevice("iPhone 14 Pro").environmentObject(IconNames())
    }
}


