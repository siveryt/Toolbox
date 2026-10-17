//
//  ToolboxApp.swift
//  Toolbox
//
//  Created by Christian Nagel on 08.03.22.
//

import SwiftUI
import WhatsNewKit
import TipKit
import SwiftData

// MARK: - App
/// The App
@main
struct App {
    @StateObject private var sbDataController = SBDataController()
    
    init() {
        // Configure TipKit before any view appears, so events donated on launch are recorded
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }
    
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
                        // fastlane snapshot launches the app with -FASTLANE_SNAPSHOT; keep the sheet out of the screenshots
                        whatsNewCollection: UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") ? [] : self.whatsNewCollection
                     )
                )
                .environmentObject(SelectedItemIndex())
                .task { IconNames.migrateRemovedIcon() }

                .modelContainer(for: [
                                    WOLDevice.self,
                                ],
                                isAutosaveEnabled: true)

        }
    }
    
}

// MARK: - App+WhatsNewCollectionProvider
extension App: WhatsNewCollectionProvider {
    
    /// A WhatsNewCollection
    var whatsNewCollection: WhatsNewCollection {
        WhatsNew(
            version: "1.4.0",
            title: .init(stringLiteral: NSLocalizedString("What's New in Toolbox", comment: "WhatsNewKit item")),
            features: [
                .init(
                    image: .init(
                        systemName: "sparkles",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("New Look", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Redesigned for iOS 26 with Liquid Glass and a fresh app icon", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "app.badge",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("App Icons", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Pick one of ten app icons in Settings, including a Pride icon", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "ruler",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Distance", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Measure the distance between two places on a map", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "metronome",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Metronome", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Keep perfect time with adjustable BPM and various time signatures", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "speaker",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Decibel Meter", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Measure sound levels to monitor noise", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "flashlight.off.fill",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Pulsing Flashlight", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Emit light pulses for enhanced visibility", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "character.magnify",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Font Installer", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Use custom fonts in other apps", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "textformat.abc",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Scrolling Text", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Display text banners to share important messages", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "power",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Wake On Lan", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Remotely power on your devices", comment: "WhatsNewKit item"))
                ),
                .init(
                    image: .init(
                        systemName: "list.bullet.indent",
                        foregroundColor: .accentColor
                    ),
                    title: .init(stringLiteral: NSLocalizedString("Your Tools, Your Order", comment: "WhatsNewKit item")),
                    subtitle: .init(stringLiteral: NSLocalizedString("Hide tools you don't use and move your favorites to the top", comment: "WhatsNewKit item"))
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
            ,
            secondaryAction: .init(
                title: .init(stringLiteral:NSLocalizedString("Learn more", comment: "WhatsNewKit item")),
                action: .openURL(.init(string: "https://toolbox.sivery.de/#version1.4"))
            )
        )
    }
    

}
