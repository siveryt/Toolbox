//
//  Counter.swift
//  Toolbox
//
//  Created by Christian Nagel on 28.03.22.
//

import SwiftUI
import Haptica
import TipKit

extension UserDefaults {

    func valueExists(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }

}

/// Explains that the whole left and right half of the screen count, not just the symbols.
struct CounterHalvesTip: Tip {
    var title: Text {
        Text(NSLocalizedString("Count Without Looking", comment: "Counter tool: tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("Tap anywhere on the right half to count up and on the left half to count down.", comment: "Counter tool: tip message explaining the tap areas"))
    }
    var image: Image? {
        Image(systemName: "hand.tap")
    }
}

struct Counter: View {
    @AppStorage("count") private var count = 0
    @State private var showAlert = false
    /// Taps in this visit; after a few the tip has done its job.
    @State private var taps = 0

    private let halvesTip = CounterHalvesTip()

    var body: some View {
        // Each half of the screen is one big button, so it can be hit without looking.
        HStack(spacing: 0) {
            CounterHalf(systemImage: "minus", alignment: .leading) { change(by: -1) }
                .accessibilityLabel(Text(NSLocalizedString("Count Down", comment: "Counter tool: accessibility label of the left half (minus)")))
            CounterHalf(systemImage: "plus", alignment: .trailing) { change(by: 1) }
                .accessibilityLabel(Text(NSLocalizedString("Count Up", comment: "Counter tool: accessibility label of the right half (plus)")))
        }
        .accessibilityValue(Text(String(count)))
        .ignoresSafeArea(edges: .bottom)
        .overlay {
            Text(String(count))
                .font(.system(size: 96, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .padding(.horizontal, 80)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .top) {
            TipView(halvesTip)
                .padding()
        }
        .alert("Reset Counter", isPresented: $showAlert) {
            Button("Don't Reset", role: .cancel) {}
            Button("Reset", role: .destructive) {
                withAnimation { count = 0 }
                Haptic.impact(.medium).generate()
            }
        } message: {
            Text("Are you sure, you want to reset the counter?")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAlert = true
                    Haptic.impact(.rigid).generate()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(count == 0)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Counter")
    }

    private func change(by delta: Int) {
        withAnimation(.snappy(duration: 0.15)) { count += delta }
        Haptic.impact(.light).generate()
        taps += 1
        if taps == 5 {
            halvesTip.invalidate(reason: .actionPerformed)
        }
    }
}

/// One half of the counter: the full area is the tap target, the symbol sits near the outer edge.
private struct CounterHalf: View {
    let systemImage: String
    let alignment: Alignment
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.largeTitle.weight(.semibold))
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .contentShape(Rectangle())
        }
        .buttonStyle(CounterHalfStyle())
    }
}

/// Lights up the whole half while it is pressed, so it is clear the entire area counts.
private struct CounterHalfStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.03))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct Counter_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Counter()
        }
    }
}
