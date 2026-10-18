//
//  Random Number.swift
//  Toolbox Watch Watch App
//
//  Created by Christian Nagel on 04.11.22.
//

import SwiftUI

struct Random_Number: View {

    @AppStorage("randomNumber") var generated = 87
    @AppStorage("from") var from = "0"
    @AppStorage("to") var to = "100"
    @State var options = false

    private var range: ClosedRange<Int> {
        let min = Int(from) ?? 0
        let max = Int(to) ?? 100
        return Swift.min(min, max)...Swift.max(min, max)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(String(generated))
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text(verbatim: "\(range.lowerBound) – \(range.upperBound)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { generateNumber() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Random Number")
        .accessibilityValue(String(generated))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { generateNumber() }
        .navigationTitle("Random Number")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { options = true }) {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Again") { generateNumber() }
                    .tint(.accentColor)
            }
        }
        // The last number may lie outside a newly edited range; don't keep showing it.
        .onChange(of: range) { keepGeneratedInRange() }
        .onAppear { keepGeneratedInRange() }
        .sheet(isPresented: $options) {
            NavigationStack {
                RangeEditor(
                    from: Binding(get: { Int(from) ?? 0 }, set: { from = String($0) }),
                    to: Binding(get: { Int(to) ?? 100 }, set: { to = String($0) })
                )
            }
        }
    }

    private func keepGeneratedInRange() {
        if !range.contains(generated) {
            generated = Int.random(in: range)
        }
    }

    func generateNumber() {
        let bounds = range
        for step in 1...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) / 20) {
                withAnimation(.snappy(duration: 0.08)) {
                    generated = Int.random(in: bounds)
                }
                if step == 6 {
                    WKInterfaceDevice.current().play(.click)
                }
            }
        }
    }
}

/// Both ends of the range side by side; tap one and turn the Digital Crown to change it.
private struct RangeEditor: View {
    @Binding var from: Int
    @Binding var to: Int
    @State private var editing = Field.from
    @State private var crown = 0.0

    private enum Field { case from, to }

    var body: some View {
        HStack(spacing: 8) {
            field(.from, title: "From", value: from)
            field(.to, title: "To", value: to)
        }
        .frame(maxHeight: .infinity)
        .focusable()
        .digitalCrownRotation($crown, from: -999, through: 9999, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) {
            let value = Int(crown.rounded())
            switch editing {
            case .from: from = value
            case .to: to = value
            }
        }
        .onAppear { crown = Double(from) }
        .navigationTitle("Settings")
    }

    private func field(_ field: Field, title: LocalizedStringKey, value: Int) -> some View {
        Button(action: {
            editing = field
            crown = Double(value)
        }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(String(value))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(editing == field ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(String(value))
        .accessibilityAddTraits(editing == field ? .isSelected : [])
        .accessibilityIdentifier(field == .from ? "range.from" : "range.to")
    }
}

struct Random_Number_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { Random_Number() }
    }
}
