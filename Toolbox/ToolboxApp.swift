//
//  ToolboxApp.swift
//  Toolbox
//
//  Created by Christian Nagel on 08.03.22.
//

import SwiftUI
import WhatsNewKit

// MARK: - App
/// The App
@main
struct App {
    @StateObject private var sbDataController = SBDataController()
    
}

// MARK: - SwiftUI.App
extension App: SwiftUI.App {
    
    
    
    /// The content and behavior of the app.
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, sbDataController.container.viewContext)
                .environment(
                    \.whatsNew,
                     .init(
                        versionStore: UserDefaultsWhatsNewVersionStore(),
                        whatsNewCollection: self
                     )
                )
        }
    }
    
}

// MARK: - App+WhatsNewCollectionProvider
extension App: WhatsNewCollectionProvider {
    
    /// A WhatsNewCollection
    var whatsNewCollection: WhatsNewCollection {
        WhatsNew(
            version: "1.3.0",
            title: .init(stringLiteral: NSLocalizedString("What's New in Toolbox", comment: "WhatsNewKit item")),
            features: [
                .init(
                    image: .init(
                        systemName: "applewatch",
                        foregroundColor: .green
                    ),
                    title: .init(stringLiteral: NSLocalizedString("WatchOS", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Enjoy some functions of the app on your wrist for easy access", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "location.fill",
                        foregroundColor: .blue
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Coordinates", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Added support for DMS coordinates and get your coordinates as a whole string", comment: "WhatsNewKit item"))
                ),
                
                .init(
                    image: .init(
                        systemName: "dice",
                        foregroundColor: .purple
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Dice", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Added a 10 sided and a 20 sided dice and dices can now be locked into place", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "magnifyingglass",
                        foregroundColor: .gray
                    ),
                    title: .init(stringLiteral: NSLocalizedString("LAN Scanner", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Check the IP of devices on your network", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "character",
                        foregroundColor: .yellow
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Random Letter", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Generate a random letter", comment: "WhatsNewKit item"))
                ),
                
                .init(
                    image: .init(
                        systemName: "barcode",
                        foregroundColor: .black
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Barcode Scanner", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Scan Barcodes, Aztec, QR-Codes and many more", comment: "WhatsNewKit item"))
                ),
                
            ],
            primaryAction: .init(
                title: .init(stringLiteral:NSLocalizedString("Continue", comment: "WhatsNewKit item")),
                hapticFeedback: {
                    #if os(iOS)
                    .notification(.success)
                    #else
                    nil
                    #endif
                }()
            )
//            ,
//            secondaryAction: .init(
//                title: "Learn more",
//                action: .openURL(.init(string: "https://github.com/SvenTiigi/WhatsNewKit"))
//            )
        )
    }
    

}
