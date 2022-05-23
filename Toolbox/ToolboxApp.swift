//
//  ToolboxApp.swift
//  Toolbox
//
//  Created by Christian Nagel on 08.03.22.
//

import SwiftUI

@main
struct ToolboxApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                .environme ntObject(IconNames())
        }
    }
}
