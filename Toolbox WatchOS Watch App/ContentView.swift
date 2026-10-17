//
//  ContentView.swift
//  Toolbox Watch Watch App
//
//  Created by Christian Nagel on 04.11.22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                toolLink("Dice", icon: "dice") { Dice() }
                toolLink("Counter", icon: "plusminus") { Counter() }
                toolLink("Random Number", icon: "number") { Random_Number() }
                toolLink("Roman Numbers", icon: "hexagon") { RomanNumbers() }
            }
            .navigationTitle("Toolbox")
        }
    }

    /// A menu row with the tool's icon in a filled circle, like the system apps.
    private func toolLink<Destination: View>(_ title: LocalizedStringKey, icon: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.accentColor.gradient))
                Text(title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("tool." + icon)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
