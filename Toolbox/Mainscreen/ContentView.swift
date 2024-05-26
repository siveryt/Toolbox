//
//  ContentView.swift
//  Toolbox
//
//  Created by Christian Nagel on 08.03.22.
//

import SwiftUI
import StoreKit
import WhatsNewKit
import TipKit

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
    @AppStorage("cvHasAlreadyEdited") var hasAlreadyEdited = false
    
    @AppStorage("cvHidden") var hidden: [Int] = []
    @AppStorage("cvHasHiddenAnythingYet") var hasHiddenAnythingYet = false
    @State var hiddenAlert = false
    
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
        Tool(view: AnyView(Metronome()), title: NSLocalizedString("Metronome", comment: "Menu item"), icon: "metronome"),
        Tool(view: AnyView(DecibelMeter()), title: NSLocalizedString("Decibel Meter", comment: "Menu item"), icon: "speaker"),
        Tool(view: AnyView(PulsingFlashlight()), title: NSLocalizedString("Pulsing Flashlight", comment: "Menu item"), icon: "flashlight.off.fill"),
        Tool(view: AnyView(FontInstall()), title: NSLocalizedString("Font Installer", comment: "Menu item"), icon: "character.magnify"),
        Tool(view: AnyView(Scrolling_Text()), title: NSLocalizedString("Scrolling Text", comment: "Menu item"), icon: "textformat.abc"),
        Tool(view: AnyView(Wake_On_Lan()), title: NSLocalizedString("Wake On Lan", comment: "Menu item"), icon: "power"),
    ]
    @State private var tools:[Tool] = []
    
    
    private func onMove(source: IndexSet, destination: Int) {
            tools.move(fromOffsets: source, toOffset: destination)
        order.move(fromOffsets: source, toOffset: destination)
        hasAlreadyEdited = true
        }
    
    var body: some View {
            NavigationView {
                List() {
                    ForEach(Array(zip(tools.indices, tools)), id: \.0) { toolIndex, tool in
                        if (!hidden.contains(toolIndex)) {
                            if (toolIndex == 0){
                                NavigationLink(destination: tools[toolIndex].view) {
                                    Label(tools[toolIndex].title, systemImage: tools[toolIndex].icon).foregroundColor(.primary)
                                }
                                .popoverTip(MainscreenMoveTip())
                                .contextMenu {
                                    Button(action:{
                                        hide(index: toolIndex)
                                    }){
                                        Label("Hide", systemImage: "eye.slash")
                                    }
                                }
                            } else {
                                NavigationLink(destination: tools[toolIndex].view) {
                                    Label(tools[toolIndex].title, systemImage: tools[toolIndex].icon).foregroundColor(.primary)
                                }
                                .contextMenu {
                                    Button(action:{
                                        hide(index: toolIndex)
                                    }){
                                        Label("Hide", systemImage: "eye.slash")
                                    }
                                }
                            }
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
                    
            }
            .onAppear() {
            
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
            
            MainscreenMoveTip.appStarts = viewLoaded
                
        }
            .alert(isPresented: $hiddenAlert) {
                Alert(
                    title: Text("Hidden Tools"),
                    message: Text("You just hid your first tool! You can still find it in the settings under \"Hidden Tools\""),
                    dismissButton: .destructive(Text("Got it!")) // I have to use .destructive and not .default, because .default often times is the default primary blue and not the color set in Assets AccentColor
                )
                    }
        .whatsNewSheet()
    }
    
    private func hide(index: Int) {
        print("Hiding \(index)")
        withAnimation{
            hidden.append(index)
        }
        if(!hasHiddenAnythingYet) {
            hasHiddenAnythingYet = true
            hiddenAlert = true
        }
    }
    
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        infoView().previewDevice("iPhone 14 Pro").environmentObject(IconNames())
    }
}


