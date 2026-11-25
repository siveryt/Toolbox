//
//  RandomNumber.swift
//  Toolbox
//
//  Created by Christian Nagel on 20.03.22.
//

import SwiftUI
import Haptica
import ToastSwiftUI

struct RandomNumber: View {

    @AppStorage("rannumMin", store: .standard) var min: Int = 1
    @AppStorage("rannumMax", store: .standard) var max: Int = 100
    @AppStorage("rannumResult", store: .standard) var result: String = ""
    /// Shows the hint until the first number is drawn, like the Dice tool.
    @AppStorage("rannumGuidance") private var guidance = true
    @State private var isPresentingToast = false
    /// What's typed into the fields; may be empty or incomplete while editing, `min` and `max` keep the last valid values.
    @State private var minText = ""
    @State private var maxText = ""
    @FocusState private var focusedField: Field?
    /// The short shuffle before a new number settles; a new draw cancels the running one.
    @State private var shuffle: Task<Void, Never>?

    private enum Field { case min, max }

    private var range: ClosedRange<Int> {
        // A closed range, so Int.max works as an upper bound
        Swift.min(min, max)...Swift.max(min, max)
    }

    var body: some View {
        VStack(spacing: 24) {
            numberButton
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls
                .frame(maxWidth: 500)
        }
        .padding()
        .avoidingActiveDivision()
        .onShake { draw() }
        .onChange(of: minText) {
            if let value = Int(minText), value != min {
                min = value
                settle()
            }
        }
        .onChange(of: maxText) {
            if let value = Int(maxText), value != max {
                max = value
                settle()
            }
        }
        .onChange(of: focusedField) {
            // An empty or invalid field shows the value that's actually used again once editing ends
            if focusedField != .min { minText = String(min) }
            if focusedField != .max { maxText = String(max) }
        }
        .onAppear {
            minText = String(min)
            maxText = String(max)
            if Int(result) == nil { settle() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: copy) {
                    Label(NSLocalizedString("Copy", comment: "LAN Scanner and Random Number: action that copies a value (an IP address, the drawn number)"), systemImage: "doc.on.doc")
                }
                .disabled(result.isEmpty)
            }
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Random Number")
    }

    /// The drawn number, as large as fits. Tapping it draws a new one.
    private var numberButton: some View {
        Button(action: draw) {
            VStack(spacing: 8) {
                Text(result)
                    .font(.system(size: 160, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(result) ?? 0))
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                if guidance {
                    Text(NSLocalizedString("Shake or Tap to Get Started", comment: "Dice, Random Letter and Random Number: hint before the first roll"))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: copy) {
                Label(NSLocalizedString("Copy", comment: "LAN Scanner and Random Number: action that copies a value (an IP address, the drawn number)"), systemImage: "doc.on.doc")
            }
        }
        .accessibilityLabel(Text("New Number"))
        .accessibilityValue(Text(result))
    }

    /// The range fields side by side, and the button that draws a new number.
    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                boundField("From", text: $minText, field: .min)
                Image(systemName: "arrow.right")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                boundField("To", text: $maxText, field: .max)
            }

            Button(action: draw) {
                Label("New Number", systemImage: "dice")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }

    private func boundField(_ title: LocalizedStringKey, text: Binding<String>, field: Field) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField("1", text: text)
                .focused($focusedField, equals: field)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .accessibilityLabel(Text(title))
                .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                    if let textField = obj.object as? UITextField {
                        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                    }
                }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = field }
    }

    /// Runs through a few numbers before settling, like a slot machine.
    private func draw() {
        focusedField = nil
        shuffle?.cancel()
        shuffle = Task { @MainActor in
            for _ in 0..<6 {
                withAnimation(.snappy(duration: 0.08)) {
                    result = String(Int.random(in: range))
                }
                Haptic.impact(.light).generate()
                try? await Task.sleep(for: .milliseconds(55))
                if Task.isCancelled { return }
            }
            settle()
            Haptic.impact(.medium).generate()
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { guidance = false }
        }
    }

    /// Sets the final number right away, e.g. after the range changed.
    private func settle() {
        shuffle?.cancel()
        withAnimation(.snappy) {
            result = String(Int.random(in: range))
        }
    }

    private func copy() {
        UIPasteboard.general.string = result
        Haptic.impact(.light).generate()
        withAnimation { isPresentingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { isPresentingToast = false }
        }
    }
}

struct RandomNumber_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RandomNumber()
        }
    }
}
