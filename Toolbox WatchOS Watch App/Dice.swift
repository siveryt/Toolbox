//
//  Dice.swift
//  Toolbox Watch Watch App
//
//  Created by Christian Nagel on 04.11.22.
//

import SwiftUI

struct Dice: View {

    @AppStorage("watchDiceSides") var sides = 6
    @AppStorage("watchDiceRolled") var rolled = 4
    @State private var settings = false

    var body: some View {
        // Uses the same dice images as the iPhone app; 10 and 20 sides share the triangle shape.
        Image("\(sides == 20 || sides == 10 ? 8 : sides)-\(min(max(rolled, 1), sides))")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { roll() }
            // VoiceOver reads "Dice, 4" and rolls with a double tap.
            .accessibilityElement()
            .accessibilityLabel("Dice")
            .accessibilityValue(String(rolled))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { roll() }
            .navigationTitle("Dice")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { settings = true }) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $settings) {
                NavigationStack {
                    Form {
                        Picker("Sides", selection: $sides) {
                            ForEach([4, 6, 8, 10, 12, 20], id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                    .navigationTitle("Settings")
                }
            }
    }

    private func roll() {
        for step in 1...9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) / 10) {
                rolled = Int.random(in: 1...sides)
                WKInterfaceDevice.current().play(.click)
            }
        }
    }
}
