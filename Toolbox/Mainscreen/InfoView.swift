//
//  InfoView.swift
//  Toolbox
//
//  Created by Christian Nagel on 05.11.22.
//

import Foundation
import SwiftUI
import CoreData
import TipKit
import Haptica
import SwiftData

struct infoView: View {
    
    @Environment(\.showingSheet) var showingSheet
    @Environment(\.managedObjectContext) var managedContext
    @Environment(\.modelContext) var modelContext
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
                
                NavigationLink(destination: infoHidden()){
                    Label("Hidden Tools", systemImage: "eye.slash")
                }
                
                Button(action: {
                    deleteAlert = true
                }) {
                    Label("Delete Data", systemImage: "trash")
                }
                .tint(.primary)
            }
            
            Section {
                Button(action: {
                    if let url = URL(string: "https://itunes.apple.com/app/id1638758005?action=write-review") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Rate app", systemImage: "star")
                }
                .tint(.primary)
                
                Button(action: {
                    shareFromSheet(shareItem: [URL(string: "https://toolbox.sivery.de/download")!])
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.primary)
                
                ExternalLinkRow("Mailing list", systemImage: "mail.stack", url: "https://mailing.sivery.de/subscription/form")
                ExternalLinkRow("Support the Development", systemImage: "heart", url: "https://toolbox.sivery.de/support")
                ExternalLinkRow("Contribute", systemImage: "person.3", url: "https://toolbox.sivery.de/contribution.html")
            }
            
            Section {
                ExternalLinkRow("Website", systemImage: "globe", url: "https://toolbox.sivery.de")

                Button(action: {
                    if let url = URL(string: "mailto:toolbox@sivery.de") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Feedback", systemImage: "mail")
                }
                .tint(.primary)

                Button(action: {
                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(appSettings)
                    }
                }) {
                    Label("OpenSource-Licenses", systemImage: "checkmark.seal")
                }
                .tint(.primary)

                ExternalLinkRow("Privacy Policy", systemImage: "lock", url: "https://toolbox.sivery.de/privacy.html")
            }
            
            Section {
                HStack {
                    Spacer()
                    Text("Made with ❤️ by Sivery")
                    Spacer()
                }
            }
            
        }
        .alert("Are you sure, you want to clear the app's data?", isPresented: $deleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let domain = Bundle.main.bundleIdentifier!
                UserDefaults.standard.removePersistentDomain(forName: domain)
                // Tips can only be reset before TipKit is configured, so the app does it on the next launch.
                UserDefaults.standard.set(true, forKey: App.resetTipsOnLaunchKey)
                UserDefaults.standard.synchronize()

                try? modelContext.delete(model: WOLDevice.self)
                try? modelContext.save()
                SBDataController.shared.resetBarcodes(context: managedContext)
                UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
                exit(-1)
            }
        } message: {
            Text("The app will close after deleting the data. You can instantly reopen it.")
        }
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
        .toolbar {
            Button(role: .close) {
                self.showingSheet?.wrappedValue = false
            }
        }
    }
}

/// A row that opens a web page in the browser, marked with an arrow at its trailing edge.
struct ExternalLinkRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let url: String
    
    init(_ title: LocalizedStringKey, systemImage: String, url: String) {
        self.title = title
        self.systemImage = systemImage
        self.url = url
    }
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .tint(.primary)
        .accessibilityAddTraits(.isLink)
    }
}

struct infoVersion: View {
    @StateObject private var icons = IconNames()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Easter egg: tapping the icon five times in a row sets off confetti.
    @State private var iconTaps = 0
    @State private var lastIconTap = Date.distantPast
    @State private var iconScale: CGFloat = 1
    @State private var celebration = 0
    @State private var celebrating = false

    var body: some View  {
        List{
            Section {
                VStack(spacing: 12) {
                    LiveAppIcon(icon: icons.currentIcon, size: 96)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .scaleEffect(iconScale)
                        .onTapGesture { iconTapped() }
                    Text(verbatim: "Toolbox")
                        .font(.title2.bold())
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }
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
                    Text(Bundle.main.infoDictionary?["GIT_COMMIT"] as? String ?? "Can't find build")
                }
                
            }
            Section {
                Button("Open AppStore", action: {
                    if let url = URL(string: "https://itunes.apple.com/app/id1638758005") {
                        UIApplication.shared.open(url)
                    }
                })
            }
        }
        
        .overlay {
            if celebrating {
                ConfettiView()
                    .id(celebration)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle("Version")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func iconTapped() {
        let now = Date()
        // Only taps in quick succession count.
        iconTaps = now.timeIntervalSince(lastIconTap) < 1.2 ? iconTaps + 1 : 1
        lastIconTap = now
        Haptic.impact(.light).generate()
        withAnimation(.spring(duration: 0.12)) { iconScale = 0.9 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(duration: 0.3, bounce: 0.6)) { iconScale = 1 }
        }
        if iconTaps == 5 {
            iconTaps = 0
            celebrate()
        }
    }
    
    private func celebrate() {
        celebration += 1
        let run = celebration
        Haptic.notification(.success).generate()
        celebrating = !reduceMotion
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            // A newer celebration keeps its own timer.
            guard run == celebration else { return }
            celebrating = false
        }
    }
}

/// Confetti that falls from the top of the screen once, drawn with Canvas so it stays cheap.
private struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let sway: Double
        let spin: Double
        let size: CGSize
        let color: Color
        let isCircle: Bool
    }
    
    @State private var pieces: [Piece] = (0..<140).map { _ in
        Piece(
            x: .random(in: 0...1),
            delay: .random(in: 0...0.8),
            speed: .random(in: 80...220),
            sway: .random(in: 0.3...1),
            spin: .random(in: 2...8),
            size: CGSize(width: .random(in: 6...11), height: .random(in: 9...16)),
            color: [Color.accentColor, .red, .orange, .yellow, .green, .blue, .purple, .pink].randomElement()!,
            isCircle: Bool.random() && Bool.random()
        )
    }
    @State private var start = Date()
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + piece.speed * t + 0.5 * 220 * t * t
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 3 + piece.x * 20) * 28 * piece.sway
                    var pieceContext = context
                    pieceContext.translateBy(x: x, y: y)
                    pieceContext.rotate(by: .radians(piece.spin * t))
                    // Squashing one axis makes the pieces look like they flip over.
                    pieceContext.scaleBy(x: cos(piece.spin * t * 0.7), y: 1)
                    let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2, width: piece.size.width, height: piece.size.height)
                    pieceContext.fill(piece.isCircle ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2), with: .color(piece.color))
                }
            }
        }
        .onAppear { start = Date() }
    }
}

struct infoHidden: View {
    @AppStorage("cvHidden") var hidden: [Int] = []
    @State var tools = ContentView().toollist
    @State var showingInfoAlert = false
    
    var body: some View {
        VStack {
            if (hidden.contains(where: tools.indices.contains)){
                List {
                    ForEach(Array(zip(tools.indices, tools)), id: \.0) { toolIndex, tool in
                        if (hidden.contains(toolIndex)) {
                            NavigationLink(destination: tools[toolIndex].view) {
                                Label(tools[toolIndex].title, systemImage: tools[toolIndex].icon).foregroundColor(.primary)
                            }
                            .contextMenu {
                                Button(action:{
                                    unhide(index: toolIndex)
                                }){
                                    Label("Show Again", systemImage: "eye")
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No Hidden Tools", systemImage: "eye.slash")
                } description: {
                    Text("Touch and hold a tool on the main screen to hide it.")
                }
            }
        }
        .navigationTitle("Hidden Tools")
        .navigationBarTitleDisplayMode(.inline)
        .alert("What?", isPresented: $showingInfoAlert) {
            Button("Got It!") { }
        } message: {
            Text("Tools you previously hid on the app's main screen can be used here.\nIf you want to move them back to the main screen, tap and hold them.\nThe same goes for hiding them again.")
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
    }
    
    private func unhide(index: Int) {
        withAnimation {
            hidden.removeAll { $0 == index }
        }
    }
}
