//
//  Counter.swift
//  Toolbox Watch Watch App
//
//  Created by Christian Nagel on 04.11.22.
//

import SwiftUI

struct Counter: View {

    @AppStorage("counted") var counted = 0
    @State var isPresentingConfirm = false
    @State private var crown = 0.0
    @State private var crownStep = 0

    var body: some View {
        // The whole screen counts up, so it's easy to hit without looking.
        Text(String(counted))
            .font(.system(size: 80, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.3)
            .lineLimit(1)
            .contentTransition(.numericText(value: Double(counted)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { count(by: 1) }
            .accessibilityElement()
            .accessibilityLabel("Counter")
            .accessibilityValue(String(counted))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { count(by: 1) }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: count(by: 1)
                case .decrement: count(by: -1)
                @unknown default: break
                }
            }
            // Turning the Digital Crown counts up or down, one step per detent.
            .focusable()
            .digitalCrownRotation($crown, from: -1_000_000, through: 1_000_000, by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crown) {
                let step = Int(crown.rounded())
                if step != crownStep {
                    withAnimation { counted += step - crownStep }
                    crownStep = step
                }
            }
            .navigationTitle("Counter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isPresentingConfirm = true }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Reset")
                    .disabled(counted == 0)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: { count(by: -1) }) {
                        Image(systemName: "minus")
                    }
                    Spacer()
                    Button(action: { count(by: 1) }) {
                        Image(systemName: "plus")
                    }
                    .tint(.accentColor)
                }
            }
            .confirmationDialog("Reset counter?", isPresented: $isPresentingConfirm) {
                Button("Reset", role: .destructive) {
                    withAnimation { counted = 0 }
                }
            }
    }

    private func count(by step: Int) {
        withAnimation { counted += step }
        WKInterfaceDevice.current().play(.click)
    }

}

struct Counter_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { Counter() }
    }
}
