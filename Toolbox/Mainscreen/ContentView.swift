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
    
    @AppStorage("cvHidden") var hidden: [Int] = []
    @AppStorage("cvHasHiddenAnythingYet") var hasHiddenAnythingYet = false
    @State var hiddenAlert = false
    @State private var searchText = ""
    @Environment(\.requestReview) private var requestReview
    
    // The order and hidden tools are saved as indices into this list, so new tools go at the end: inserting one shifts every saved index after it.
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
        Tool(view: AnyView(Distance()), title: NSLocalizedString("Distance", comment: "Menu item"), icon: "ruler"),
        Tool(view: AnyView(FullscreenCamera()), title: NSLocalizedString("Fullscreen Camera", comment: "Menu item"), icon: "camera.viewfinder"),
    ]
    
    /// The saved order of indices into `toollist`, without duplicates or indices that no longer exist, followed by tools that are new since it was saved.
    private var orderedIDs: [Int] {
        var seen = Set<Int>()
        let kept = order.filter { toollist.indices.contains($0) && seen.insert($0).inserted }
        return kept + toollist.indices.filter { !seen.contains($0) }
    }
    
    private var visibleIDs: [Int] {
        orderedIDs.filter { !hidden.contains($0) && matchesSearch(toollist[$0]) }
    }
    
    /// Hidden tools that match the search, so searching still finds them.
    private var hiddenMatchIDs: [Int] {
        searchText.isEmpty ? [] : orderedIDs.filter { hidden.contains($0) && matchesSearch(toollist[$0]) }
    }
    
    // The offsets count only the visible rows, so move those and put them back into the slots they held in the full order.
    private func onMove(source: IndexSet, destination: Int) {
        var moved = visibleIDs
        moved.move(fromOffsets: source, toOffset: destination)
        var remaining = moved.makeIterator()
        order = orderedIDs.map { visibleIDs.contains($0) ? remaining.next()! : $0 }
        MainscreenMoveTip().invalidate(reason: .actionPerformed)
    }
    
    var body: some View {
            NavigationStack {
                List() {
                    // Rows are identified by their index in `toollist`, not their position, so SwiftUI animates moves correctly.
                    ForEach(visibleIDs, id: \.self) { toolID in
                        let tool = toollist[toolID]
                        if (toolID == visibleIDs.first){
                            NavigationLink(destination: tool.view) {
                                Label(tool.title, systemImage: tool.icon).foregroundColor(.primary)
                            }
                            .accessibilityIdentifier("tool." + tool.icon)
                            .popoverTip(MainscreenMoveTip())
                            .contextMenu {
                                Button(action:{
                                    hide(index: toolID)
                                }){
                                    Label("Hide", systemImage: "eye.slash")
                                }
                            }
                        } else {
                            NavigationLink(destination: tool.view) {
                                Label(tool.title, systemImage: tool.icon).foregroundColor(.primary)
                            }
                            .accessibilityIdentifier("tool." + tool.icon)
                            .contextMenu {
                                Button(action:{
                                    hide(index: toolID)
                                }){
                                    Label("Hide", systemImage: "eye.slash")
                                }
                            }
                        }
                    }
                    .onMove(perform: searchText.isEmpty ? onMove : nil)
                    
                    if !hiddenMatchIDs.isEmpty {
                        Section("Hidden Tools") {
                            ForEach(hiddenMatchIDs, id: \.self) { toolID in
                                let tool = toollist[toolID]
                                NavigationLink(destination: tool.view) {
                                    Label(tool.title, systemImage: tool.icon).foregroundColor(.secondary)
                                }
                                .contextMenu {
                                    Button(action: {
                                        withAnimation {
                                            hidden.removeAll { $0 == toolID }
                                        }
                                    }) {
                                        Label("Show Again", systemImage: "eye")
                                    }
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText)
                .overlay {
                    if (!searchText.isEmpty && visibleIDs.isEmpty && hiddenMatchIDs.isEmpty) {
                        ContentUnavailableView.search(text: searchText)
                    } else if (searchText.isEmpty && visibleIDs.isEmpty) {
                        ContentUnavailableView {
                            Label(NSLocalizedString("All Tools Hidden", comment: "Main screen: title shown when the user has hidden every tool"), systemImage: "eye.slash")
                        } description: {
                            Text(NSLocalizedString("You can show them again in the settings under \"Hidden Tools\".", comment: "Main screen: hint shown when the user has hidden every tool"))
                        }
                    }
                }
                
                .sheet(isPresented: $infoPresented){
                    NavigationStack{
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
            }
            .onAppear() {
            
            if(order != orderedIDs) {
                order = orderedIDs
            }
            
            viewLoaded += 1
            MainscreenMoveTip.appStarted.sendDonation()
            
            if [5, 50, 150, 300].contains(viewLoaded) {
                requestReview()
            }
                
        }
            .alert("Hidden Tools", isPresented: $hiddenAlert) {
                Button("Got It!") { }
            } message: {
                Text("You just hid your first tool! You can still find it in the settings under \"Hidden Tools\".")
            }
        .whatsNewSheet()
    }
    
    private func matchesSearch(_ tool: Tool) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return query.isEmpty || tool.title.localizedStandardContains(query)
    }
    
    private func hide(index: Int) {
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


