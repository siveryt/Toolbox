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
                        versionStore: InMemoryWhatsNewVersionStore(),
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
                    title: "OpenSource",
                    subtitle: "Toolbox has gone fully OpenSource and it's source code is available through GitHub"
                ),
                .init(
                    image: .init(
                        systemName: "gear.circle.fill",
                        foregroundColor: .gray
                    ),
                    title: "Configuration",
                    subtitle: "Reorder tools the way you like it"
                ),
                .init(
                    image: .init(
                        systemName: "bolt.horizontal.fill",
                        foregroundColor: .yellow
                    ),
                    title: "Ping",
                    subtitle: "Test the latency between you and a server"
                ),
                .init(
                    image: .init(
                        systemName: "location.fill",
                        foregroundColor: .blue
                    ),
                    title: "Coordinates",
                    subtitle: "Get your exact coordinates from your iPhone's GPS sensor"
                ),
                .init(
                    image: .init(
                        systemName: "speedometer",
                        foregroundColor: .red
                    ),
                    title: "Speed",
                    subtitle: "Get your current speed calculated from your GPS coordinates"
                ),
                .init(
                    image: .init(
                        systemName: "applewatch",
                        foregroundColor: .green
                    ),
                    title: "WatchOS",
                    subtitle: "Get some basic features onto your wrist for easy access"
                )
            ],
            primaryAction: .init(
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
