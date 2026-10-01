//
//  ContentView.swift
//  Toolbox Watch Watch App
//
//  Created by Christian Nagel on 04.11.22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        
        NavigationView {
            List {
                
                NavigationLink(destination: Dice()) {
                        Label("Dice", systemImage: "dice").foregroundColor(.primary)
                    }
                .accessibilityIdentifier("tool.dice")
                NavigationLink(destination: Counter()) {
                    Label("Counter", systemImage: "plusminus").foregroundColor(.primary)
                }
                .accessibilityIdentifier("tool.plusminus")
                NavigationLink(destination: Random_Number()) {
                    Label("Random Number", systemImage: "number").foregroundColor(.primary)
                }
                .accessibilityIdentifier("tool.number")
            }
            
            .navigationTitle("Toolbox")
        }
        
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
