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
struct App {}

// MARK: - SwiftUI.App
extension App: SwiftUI.App {
    
    /// The content and behavior of the app.
    var body: some Scene {
        WindowGroup {
            ContentView()
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
            version: "1.2.0",
            title: "What's New in Toolbox",
            features: [
                
                .init(
                    image: .init(
                        systemName: "person.fill",
                        foregroundColor: .purple
                    ),
                    title: .init(stringLiteral: NSLocalizedString("OpenSource", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Toolbox has gone fully OpenSource and it's source code is available through GitHub", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "gear.circle.fill",
                        foregroundColor: .gray
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Configuration", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Reorder tools the way you like it", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "bolt.horizontal.fill",
                        foregroundColor: .yellow
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Ping", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Test the latency between you and a server", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "location.fill",
                        foregroundColor: .blue
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Coordinates", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Get your exact coordinates from your iPhone's GPS sensor", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "speedometer",
                        foregroundColor: .red
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Speed", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Get your current speed calculated from your GPS coordinates", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "applewatch",
                        foregroundColor: .green
                    ),
                    title: .init(stringLiteral: NSLocalizedString("WatchOS", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Get some basic features onto your wrist for easy access", comment: "WhatsNewKit item"))
                )
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
