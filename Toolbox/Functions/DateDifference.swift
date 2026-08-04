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
                        DatePicker("Start Date", selection: $dateFrom, displayedComponents: [.date])
                        Divider()
                        DatePicker("End Date", selection: $dateTo, displayedComponents: [.date])
                    }
                }

                // Unit selection
                section(NSLocalizedString("Show", comment: "Date difference")) {
                    HStack(spacing: 8) {
                        UnitChip(title: NSLocalizedString("Years", comment: "Date difference"),
                                 isOn: displayYears) { toggleUnit($displayYears) }
                        UnitChip(title: NSLocalizedString("Months", comment: "Date difference"),
                                 isOn: displayMonths) { toggleUnit($displayMonths) }
                        UnitChip(title: NSLocalizedString("Days", comment: "Date difference"),
                                 isOn: displayDays) { toggleUnit($displayDays) }
                    }
                }

                // Result
                section(NSLocalizedString("Difference", comment: "Date difference")) {
                    Button {
                        let text = units.map { "\(value($0, in: diff)) \($0.label)" }.joined(separator: ", ")
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
                                        Text(unit.label.uppercased())
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
        .navigationTitle("Date Difference")
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

    var label: String {
        switch self {
        case .years: return NSLocalizedString("Years", comment: "Date difference")
        case .months: return NSLocalizedString("Months", comment: "Date difference")
        case .days: return NSLocalizedString("Days", comment: "Date difference")
        }
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
