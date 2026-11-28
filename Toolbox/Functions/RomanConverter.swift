import SwiftUI
import Haptica
import ToastSwiftUI

/// Converts between Arabic numbers and Roman numerals (1–3999) in both directions, with its own keypads.
struct RomanConverter: View {
    /// What's typed in each mode. Only the one of the current mode is up to date, the other is filled in when switching.
    @AppStorage("romanArabic") private var arabic = ""
    @AppStorage("romanRoman") private var roman = ""
    @AppStorage("romanInput") private var input: Field = .arabic
    @State private var isPresentingToast = false
    @FocusState private var hasKeyboardFocus: Bool

    enum Field: String { case arabic, roman }

    /// The number that's typed in, whichever way; may be 0 or too big when typed as an Arabic number.
    private var value: Int? {
        switch input {
        case .arabic: Int(arabic)
        case .roman: Roman.value(of: roman)
        }
    }

    /// A Roman numeral is typed that isn't a correctly written one, like IIII or VX.
    private var isInvalidNumeral: Bool { input == .roman && !roman.isEmpty && value == nil }

    /// The standard Roman numeral of `value`, if it has one.
    private var numeral: String? { value.flatMap(Roman.numeral(for:)) }

    var body: some View {
        VStack(spacing: 16) {
            displays
                .frame(maxHeight: .infinity)
            keypad
                .frame(height: 290)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .padding()
        .avoidingActiveDivision()
        .focusable()
        .focusEffectDisabled()
        .focused($hasKeyboardFocus)
        .onKeyPress(phases: .down, action: handleKey)
        .onAppear { hasKeyboardFocus = true }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { copy(input == .arabic ? numeral : value.map(String.init)) }) {
                    Label(NSLocalizedString("Copy", comment: "LAN Scanner and Random Number: action that copies a value (an IP address, the drawn number)"), systemImage: "doc.on.doc")
                }
                .disabled(numeral == nil)
            }
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Roman Numbers")
    }

    // MARK: - Displays

    private var displays: some View {
        // Anchored at the top, so the fields stay put while the hint below comes and goes
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                card(.arabic)
                card(.roman)
            }
            .overlay { swapButton }
            .layoutPriority(1)

            status
                .frame(minHeight: 44)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    /// One side of the conversion. The one being typed into is highlighted; tapping the other one switches to it.
    private func card(_ field: Field) -> some View {
        let isInput = input == field
        let text: String? = switch field {
        case .arabic: (isInput ? Int(arabic) : value)?.formatted()
        case .roman: isInput ? (roman.isEmpty ? nil : roman) : numeral
        }
        let title = field == .arabic
            ? NSLocalizedString("Arabic", comment: "Roman Numbers tool: label of the field for regular (Arabic) numbers like 2024")
            : NSLocalizedString("Roman", comment: "Roman Numbers tool: label of the field for Roman numerals")

        return Button(action: { switchInput(to: field) }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isInput ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(text ?? (field == .arabic ? "0" : "–"))
                    .font(field == .arabic
                        ? .system(size: 56, weight: .bold, design: .rounded)
                        : .system(size: 56, weight: .semibold, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(text == nil ? AnyShapeStyle(.tertiary) : isInput && isInvalidNumeral ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                    .contentTransition(field == .arabic ? .numericText(value: Double(value ?? 0)) : .opacity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            // Keeps the swap button, which sits on the edge between the two cards, clear of the number
            .padding(.bottom, field == .arabic ? 26 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.fill.quaternary)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.tint, lineWidth: isInput ? 2 : 0)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let text, text != "0" {
                Button(action: { copy(field == .arabic ? value.map(String.init) : text) }) {
                    Label(NSLocalizedString("Copy", comment: "LAN Scanner and Random Number: action that copies a value (an IP address, the drawn number)"), systemImage: "doc.on.doc")
                }
            }
        }
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(verbatim: text ?? ""))
        .accessibilityAddTraits(isInput ? .isSelected : [])
    }

    private var swapButton: some View {
        Button(action: { switchInput(to: input == .arabic ? .roman : .arabic) }) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.headline)
                .rotationEffect(.degrees(input == .arabic ? 0 : 180))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text(NSLocalizedString("Swap", comment: "Roman Numbers tool: button between the two fields that switches between typing an Arabic number and typing a Roman numeral")))
    }

    /// Explains why there's no conversion.
    @ViewBuilder
    private var status: some View {
        if let value, value > Roman.maximum {
            message(NSLocalizedString("You can't convert numbers bigger than 3999.", comment: "Roman Numbers tool: shown when the entered number is too big"), color: .red)
        } else if value == 0 {
            message(NSLocalizedString("There is no zero in Roman numerals.", comment: "Roman Numbers tool: shown when 0 is entered"), color: .orange)
        } else if isInvalidNumeral {
            message(NSLocalizedString("Not a valid Roman numeral.", comment: "Roman Numbers tool: shown when the entered Roman numeral isn't written correctly, like IIII or VX"), color: .red)
        }
    }

    private func message(_ text: String, color: Color) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }

    // MARK: - Keypads

    @ViewBuilder
    private var keypad: some View {
        switch input {
        case .arabic: arabicKeypad
        case .roman: romanKeypad
        }
    }

    private var arabicKeypad: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]], id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { digit in
                        key(action: { type(digit) }) {
                            Text(digit).font(.system(.title, design: .rounded).weight(.medium))
                        }
                    }
                }
            }
            GridRow {
                clearKey
                key(action: { type("0") }) {
                    Text("0").font(.system(.title, design: .rounded).weight(.medium))
                }
                deleteKey
            }
        }
    }

    private var romanKeypad: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow { letterKey("I"); letterKey("V"); letterKey("X"); letterKey("L") }
            GridRow { letterKey("C"); letterKey("D"); letterKey("M"); deleteKey }
            GridRow {
                clearKey.gridCellColumns(4)
            }
        }
    }

    /// A Roman digit with its value underneath.
    private func letterKey(_ letter: Character) -> some View {
        let symbol = String(letter)
        let amount = Roman.values[letter]!
        return key(action: { type(symbol) }) {
            VStack(spacing: 0) {
                Text(symbol)
                    .font(.system(.title, design: .serif).weight(.semibold))
                Text(amount.formatted())
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(Text(symbol))
        .accessibilityValue(Text(amount.formatted()))
    }

    private var clearKey: some View {
        key(action: clear) {
            Text(NSLocalizedString("Clear", comment: "Roman Numbers tool: keypad key that empties the input"))
                .font(.headline)
        }
        .disabled(input == .arabic ? arabic.isEmpty : roman.isEmpty)
    }

    private var deleteKey: some View {
        key(action: deleteLast) {
            Image(systemName: "delete.left")
                .font(.title2)
        }
        .disabled(input == .arabic ? arabic.isEmpty : roman.isEmpty)
        .accessibilityLabel(Text(NSLocalizedString("Delete", comment: "Generic delete action: Info screen button that deletes all app data, Wake On Lan context menu that deletes a device, and the backspace key of the Apple Watch Roman Numbers keypad")))
    }

    private func key(action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: {
            Haptic.impact(.light).generate()
            action()
        }) {
            label()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(KeyStyle())
    }

    // MARK: - Input

    private func type(_ symbol: String) {
        withAnimation(.snappy(duration: 0.2)) {
            switch input {
            case .arabic:
                // Four digits are enough to reach the maximum, and no leading zeros
                if arabic == "0" { arabic = "" }
                if arabic.count < 4 { arabic += symbol }
            case .roman:
                // MMMDCCCLXXXVIII (3888) is the longest numeral
                if roman.count < 15 { roman += symbol }
            }
        }
    }

    private func deleteLast() {
        withAnimation(.snappy(duration: 0.2)) {
            switch input {
            case .arabic: _ = arabic.popLast()
            case .roman: _ = roman.popLast()
            }
        }
    }

    private func clear() {
        withAnimation(.snappy) {
            switch input {
            case .arabic: arabic = ""
            case .roman: roman = ""
            }
        }
    }

    /// Continues with the converted value on the other side, so swapping keeps the number.
    private func switchInput(to field: Field) {
        guard field != input else { return }
        withAnimation(.snappy) {
            switch field {
            case .roman: roman = numeral ?? ""
            case .arabic: arabic = value.map(String.init) ?? ""
            }
            input = field
        }
        Haptic.impact(.light).generate()
    }

    /// Typing on a hardware keyboard: digits and Roman letters go to their side, Delete and Escape edit.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .delete {
            deleteLast()
            return .handled
        }
        if press.key == .escape {
            clear()
            return .handled
        }
        guard press.modifiers.isDisjoint(with: [.command, .control, .option]),
              let character = press.characters.uppercased().first
        else { return .ignored }

        if character.isASCII, character.isNumber {
            switchInput(to: .arabic)
            type(String(character))
            return .handled
        }
        if Roman.values[character] != nil {
            switchInput(to: .roman)
            type(String(character))
            return .handled
        }
        return .ignored
    }

    private func copy(_ text: String?) {
        guard let text else { return }
        UIPasteboard.general.string = text
        Haptic.impact(.light).generate()
        withAnimation { isPresentingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { isPresentingToast = false }
        }
    }
}

/// A big rounded key like on the system keypads.
private struct KeyStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.fill.tertiary)
                    .opacity(configuration.isPressed ? 0.6 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Roman numerals from 1 to 3999.
enum Roman {
    static let maximum = 3999

    static let values: [Character: Int] = ["I": 1, "V": 5, "X": 10, "L": 50, "C": 100, "D": 500, "M": 1000]

    private static let symbols: [(Int, String)] = [
        (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
        (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
        (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I"),
    ]

    /// The numeral, or nil for 0 and numbers above `maximum`.
    static func numeral(for value: Int) -> String? {
        guard (1...maximum).contains(value) else { return nil }
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

    /// The value of a correctly written numeral, or nil for anything else like "IIII" or "VX".
    static func value(of numeral: String) -> Int? {
        let digits = numeral.compactMap { values[$0] }
        guard !digits.isEmpty, digits.count == numeral.count else { return nil }
        var total = 0
        for (i, digit) in digits.enumerated() {
            total += i + 1 < digits.count && digit < digits[i + 1] ? -digit : digit
        }
        // Only the standard spelling, so the conversion works both ways
        return Self.numeral(for: total) == numeral ? total : nil
    }
}

struct RomanConverter_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RomanConverter()
        }
    }
}
