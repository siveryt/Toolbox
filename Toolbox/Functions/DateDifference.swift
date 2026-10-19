import SwiftUI
import Foundation
import Haptica
import ToastSwiftUI

struct DateDifference: View{
    func removeTimeFromDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? Date()
    }
    func calcDiff(from start: Date, to end: Date) -> (years: Int, months: Int, days: Int) {
        let calendar = Calendar.current

        let startDate = removeTimeFromDate(min(start, end))
        let endDate = removeTimeFromDate(max(start, end))

        var elements: Set<Calendar.Component> = []
        if(displayDays) {
            elements.insert(Calendar.Component.day)
        }
        if(displayYears) {
            elements.insert(Calendar.Component.year)
        }
        if(displayMonths) {
            elements.insert(Calendar.Component.month)
        }

        let components = calendar.dateComponents(elements, from: startDate, to: endDate)

        return (years: components.year ?? 0, months: components.month ?? 0, days: components.day ?? 0)
    }

    @State private var dateFrom = Date()
    @State private var dateTo = Date()
    @AppStorage("dateDiffYears") var displayYears = true
    @AppStorage("dateDiffMonths") var displayMonths = true
    @AppStorage("dateDiffDays") var displayDays = true
    @State var isPresentingToast: Bool = false

    func presentToast() {
        withAnimation {
            isPresentingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isPresentingToast = false
            }
        }
    }

    /// Flips one unit on/off, but never lets the user disable the last remaining unit.
    /// The animation is declarative (`.animation(_:value:)` on the grid / chip) rather than
    /// wrapped here — that is what actually plays now that the result lives in a `ScrollView`
    /// instead of a `Form`, whose list cells suppress internal insert/remove transitions.
    private func toggleUnit(_ binding: Binding<Bool>) {
        let activeCount = [displayYears, displayMonths, displayDays].filter { $0 }.count
        if binding.wrappedValue && activeCount <= 1 { return }
        Haptic.impact(.light).generate()
        binding.wrappedValue.toggle()
    }

    private func isOn(_ unit: DiffUnit) -> Bool {
        switch unit {
        case .years: return displayYears
        case .months: return displayMonths
        case .days: return displayDays
        }
    }

    private func value(_ unit: DiffUnit, in diff: (years: Int, months: Int, days: Int)) -> Int {
        switch unit {
        case .years: return diff.years
        case .months: return diff.months
        case .days: return diff.days
        }
    }

    /// Active units in reading order (largest first) for both the result grid and the copy string.
    private var activeUnits: [DiffUnit] {
        DiffUnit.allCases.filter { isOn($0) }
    }

    var body: some View{

        let diff = calcDiff(from: dateFrom, to: dateTo)
        let units = activeUnits

        ScrollView {
            VStack(spacing: 26) {

                // Dates
                card {
                    VStack(spacing: 14) {
                        DatePicker(NSLocalizedString("Start Date", comment: "Date Difference: date picker label"), selection: $dateFrom, displayedComponents: [.date])
                        Divider()
                        DatePicker(NSLocalizedString("End Date", comment: "Date Difference: date picker label"), selection: $dateTo, displayedComponents: [.date])
                    }
                }

                // Unit selection
                section(NSLocalizedString("Show", comment: "Date Difference tool: header above the chips (years, months, days) that choose which units the result is shown in")) {
                    HStack(spacing: 8) {
                        UnitChip(title: NSLocalizedString("Years", comment: "Date Difference tool: chip that shows or hides the years in the result"),
                                 isOn: displayYears) { toggleUnit($displayYears) }
                        UnitChip(title: NSLocalizedString("Months", comment: "Date Difference tool: chip that shows or hides the months in the result"),
                                 isOn: displayMonths) { toggleUnit($displayMonths) }
                        UnitChip(title: NSLocalizedString("Days", comment: "Date Difference tool: chip that shows or hides the days in the result"),
                                 isOn: displayDays) { toggleUnit($displayDays) }
                    }
                }

                // Result
                section(NSLocalizedString("Difference", comment: "Date Difference tool: header above the result")) {
                    Button {
                        let text = units.map { $0.copyText(value($0, in: diff)) }.joined(separator: ", ")
                        UIPasteboard.general.string = text
                        Haptic.impact(.light).generate()
                        presentToast()
                    } label: {
                        HStack(spacing: 0) {
                            ForEach(units) { unit in
                                HStack(spacing: 0) {
                                    if unit != units.first {
                                        Divider().frame(height: 36)
                                    }
                                    VStack(spacing: 4) {
                                        Text("\(value(unit, in: diff))")
                                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                            .contentTransition(.numericText())
                                            .monospacedDigit()
                                        Text(unit.label(for: value(unit, in: diff)).uppercased())
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(.snappy, value: units)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 22)
        }
        .background(Color(.systemGroupedBackground))
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(NSLocalizedString("Date Difference", comment: "Menu item"))
    }

    /// A white, rounded grouped card — mirrors the look of the app's `Form` rows so the
    /// screen fits in, while living outside a `List` so animations aren't suppressed.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    /// A grouped card with a leading, uppercase section header above it — the `Form` look.
    private func section<Content: View>(_ header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.footnote)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
            card(content)
        }
    }
}

/// The three units the difference can be broken down into, in reading order (largest first).
/// A stable, per-unit identity is what keeps the result grid animating cleanly as units are
/// toggled — index-based identity makes SwiftUI treat a removal as an in-place content change.
private enum DiffUnit: String, CaseIterable, Identifiable {
    case years, months, days

    var id: String { rawValue }

    /// The unit name under the number in the result, in singular or plural to match it ("1 YEAR", "2 YEARS").
    func label(for count: Int) -> String {
        // Xcode only allows plural variations for strings that contain the number, so take the unit from the
        // pluralized "%lld years" string and drop the number, which is shown separately above.
        let unit = copyText(count)
            // Formatted like the number in copyText, which groups digits ("1,234 days")
            .replacingOccurrences(of: String.localizedStringWithFormat("%lld", count), with: "")
            .trimmingCharacters(in: .whitespaces)
        return unit.prefix(1).uppercased(with: .current) + unit.dropFirst()
    }

    /// Number and unit for the copied result, e.g. "1 year" or "3 days".
    func copyText(_ count: Int) -> String {
        let format: String
        switch self {
        case .years: format = NSLocalizedString("%lld years", comment: "Date Difference tool: number of years in the copied result, e.g. “1 year, 2 months, 3 days”")
        case .months: format = NSLocalizedString("%lld months", comment: "Date Difference tool: number of months in the copied result, e.g. “1 year, 2 months, 3 days”")
        case .days: format = NSLocalizedString("%lld days", comment: "Date Difference tool: number of days in the copied result, e.g. “1 year, 2 months, 3 days”")
        }
        return String.localizedStringWithFormat(format, count)
    }
}

/// A tappable, capsule-shaped unit selector that fills with the accent colour when active.
private struct UnitChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isOn ? Color.accentColor : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .animation(.snappy, value: isOn)
        }
        .buttonStyle(ChipButtonStyle())
    }
}

/// Gives the chips a subtle, consistent press-down feedback instead of the default fade.
private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
