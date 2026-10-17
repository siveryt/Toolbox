//
//  RomanNumbers.swift
//  Toolbox WatchOS Watch App
//

import SwiftUI

/// Turn the Digital Crown to pick a number and see it as a Roman numeral.
struct RomanNumbers: View {

    @AppStorage("watchRomanNumber") var number = 2026
    @State private var crown = 2026.0
    @State private var entering = false

    private let range = 1...3999

    var body: some View {
        VStack(spacing: 4) {
            Text(Self.roman(number))
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(number)))
            Text(String(number))
                .font(.title3)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(number)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(number))
        .accessibilityValue(Self.roman(number))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(min(number + 1, range.upperBound))
            case .decrement: set(max(number - 1, range.lowerBound))
            @unknown default: break
            }
        }
        .focusable()
        .digitalCrownRotation($crown, from: Double(range.lowerBound), through: Double(range.upperBound), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) {
            let value = Int(crown.rounded())
            if value != number {
                withAnimation(.snappy(duration: 0.15)) { number = value }
            }
        }
        .onAppear { crown = Double(number) }
        .navigationTitle("Roman Numbers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { entering = true }) {
                    Image(systemName: "character.cursor.ibeam")
                }
                .accessibilityLabel("Roman")
            }
        }
        .sheet(isPresented: $entering) {
            NavigationStack {
                RomanKeypad { set($0) }
                    .navigationTitle("Roman")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func set(_ value: Int) {
        withAnimation(.snappy(duration: 0.15)) { number = value }
        crown = Double(value)
    }

    static let symbols: [(Int, String)] = [
        (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
        (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
        (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I"),
    ]

    static func roman(_ value: Int) -> String {
        var rest = value
        var result = ""
        for (amount, symbol) in symbols {
            while rest >= amount {
                result += symbol
                rest -= amount
            }
        }
        return result
    }

    /// The value of a correctly written Roman numeral (1–3999), or nil for anything else like "IIII" or "VX".
    static func arabic(_ roman: String) -> Int? {
        let values: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100, "D": 500, "M": 1000]
        let digits = roman.compactMap { values[$0] }
        guard !digits.isEmpty, digits.count == roman.count else { return nil }
        var total = 0
        for (i, digit) in digits.enumerated() {
            total += i + 1 < digits.count && digit < digits[i + 1] ? -digit : digit
        }
        // Only accept the standard spelling, so the conversion works both ways.
        return (1...3999).contains(total) && Self.roman(total) == roman ? total : nil
    }
}

/// A keypad with only the seven Roman digits, so there's nothing else to type.
private struct RomanKeypad: View {
    let onDone: (Int) -> Void
    @State private var input = ""
    @Environment(\.dismiss) private var dismiss

    private var value: Int? { RomanNumbers.arabic(input) }

    var body: some View {
        VStack(spacing: 5) {
            // The entered numeral and its value on one line, red while it isn't a valid numeral.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(input.isEmpty ? " " : input)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(input.isEmpty || value != nil ? Color.primary : Color.red)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                if let value {
                    Text(String(value))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 26)
            .accessibilityElement(children: .combine)

            Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                GridRow { key("I"); key("V"); key("X") }
                GridRow { key("L"); key("C"); key("D") }
                GridRow {
                    key("M")
                    Button(action: { _ = input.popLast() }) {
                        Image(systemName: "delete.left")
                    }
                    .buttonStyle(KeyStyle())
                    .disabled(input.isEmpty)
                    .accessibilityLabel("Delete")
                    .accessibilityIdentifier("roman.delete")
                    Button(action: {
                        if let value {
                            onDone(value)
                            dismiss()
                        }
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(KeyStyle(tint: .accentColor))
                    .disabled(value == nil)
                    .accessibilityLabel("Done")
                    .accessibilityIdentifier("roman.done")
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func key(_ digit: String) -> some View {
        Button(action: {
            if input.count < 15 { input += digit }
            WKInterfaceDevice.current().play(.click)
        }) {
            Text(digit)
                .font(.system(.title3, design: .serif).weight(.semibold))
        }
        .buttonStyle(KeyStyle())
    }
}

/// A compact key, so three rows fit below the title on every watch size.
private struct KeyStyle: ButtonStyle {
    var tint: Color?
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let color = tint ?? .white
        configuration.label
            .foregroundStyle(tint ?? .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(configuration.isPressed ? 0.35 : (tint == nil ? 0.14 : 0.24)))
            )
            .opacity(isEnabled ? 1 : 0.4)
    }
}

struct RomanNumbers_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { RomanNumbers() }
    }
}
