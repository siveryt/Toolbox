//
//  BirthdayWidget.swift
//  diceWidget
//
//  Birthday Buddy on the Home Screen and Lock Screen: the next birthdays from the contacts.
//  The extension reads the contacts itself, with the permission the user gave the app.
//

import WidgetKit
import SwiftUI

struct BirthdayEntry: TimelineEntry {
    let date: Date
    /// Sorted by the next birthday after `date`; empty when there are none.
    let birthdays: [Birthday]
    let hasAccess: Bool
}

struct BirthdayProvider: TimelineProvider {
    /// More than the large widget shows, so every entry of the week still has enough.
    private let kept = 12

    func placeholder(in context: Context) -> BirthdayEntry {
        BirthdayEntry(date: .now, birthdays: Self.examples, hasAccess: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BirthdayEntry) -> Void) {
        let entry = load(at: .now)
        // The widget gallery shows examples until there is something real to show.
        if context.isPreview && entry.birthdays.isEmpty {
            completion(placeholder(in: context))
        } else {
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BirthdayEntry>) -> Void) {
        let calendar = Birthday.calendar
        let today = calendar.startOfDay(for: .now)
        let first = load(at: .now)
        // "in 3 days" changes at midnight, so there is an entry for each of the next days.
        var entries = [first]
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            entries.append(BirthdayEntry(date: day, birthdays: Array(Birthday.upcoming(first.birthdays, from: day).prefix(kept)), hasAccess: first.hasAccess))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func load(at date: Date) -> BirthdayEntry {
        guard Birthday.hasContactAccess else { return BirthdayEntry(date: date, birthdays: [], hasAccess: false) }
        let all = (try? Birthday.fetchAll(thumbnails: false)) ?? []
        // Within the next week the order can change, so keep a few more than are shown.
        var soonest = Array(Birthday.upcoming(all, from: date).prefix(kept))
        let pictures = Birthday.thumbnails(for: soonest.map(\.id))
        for i in soonest.indices { soonest[i].thumbnail = pictures[soonest[i].id] }
        return BirthdayEntry(date: date, birthdays: soonest, hasAccess: true)
    }

    static let examples = [
        Birthday(id: "1", name: "Anna Muster", month: 1, day: 1, year: 1990, thumbnail: nil),
        Birthday(id: "2", name: "Ben Beispiel", month: 1, day: 4, year: 1985, thumbnail: nil),
        Birthday(id: "3", name: "Otto Ohnejahr", month: 1, day: 20, year: nil, thumbnail: nil),
        Birthday(id: "4", name: "Lea Leap", month: 2, day: 29, year: 2000, thumbnail: nil),
    ].map { birthday in
        // Dates relative to today, so the examples always look upcoming.
        let offsets = ["1": 0, "2": 3, "3": 12, "4": 40]
        let date = Birthday.calendar.date(byAdding: .day, value: offsets[birthday.id] ?? 0, to: .now) ?? .now
        let parts = Birthday.calendar.dateComponents([.month, .day], from: date)
        return Birthday(id: birthday.id, name: birthday.name, month: parts.month ?? 1, day: parts.day ?? 1, year: birthday.year, thumbnail: nil)
    }
}

// MARK: - Texts

private extension Birthday {
    func whenText(from date: Date) -> String {
        let days = daysUntilNext(from: date)
        return days == 0
            ? NSLocalizedString("Today 🎉", comment: "Birthday Buddy list: shown next to a contact whose birthday is today")
            : Birthday.relativeDays(days)
    }

    func ageText(from date: Date) -> String? {
        ageOnNext(from: date).map {
            String(format: NSLocalizedString("turns %lld", comment: "Birthday Buddy list: the age the contact turns on their next birthday"), $0)
        }
    }

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

// MARK: - Views

private struct Avatar: View {
    let birthday: Birthday
    let size: CGFloat

    var body: some View {
        Group {
            if let data = birthday.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(birthday.initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.red.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .widgetAccentable()
    }
}

private struct EmptyState: View {
    let hasAccess: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: hasAccess ? "gift" : "person.crop.circle.badge.questionmark")
                .font(.title2)
                .foregroundStyle(.red)
            Text(hasAccess
                 ? NSLocalizedString("No Birthdays", comment: "Birthday Buddy: title when no contact has a birthday")
                 : NSLocalizedString("Open Birthday Buddy to see your contacts' birthdays.", comment: "Birthday Buddy widget: shown until the app has access to the contacts"))
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SmallView: View {
    let entry: BirthdayEntry

    var body: some View {
        if let next = entry.birthdays.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Avatar(birthday: next, size: 44)
                    Spacer()
                    Image(systemName: "gift.fill")
                        .foregroundStyle(.red)
                        .widgetAccentable()
                }
                Spacer(minLength: 0)
                Text(next.name)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(next.whenText(from: entry.date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .widgetAccentable()
                if let age = next.ageText(from: entry.date) {
                    Text(age)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            EmptyState(hasAccess: entry.hasAccess)
        }
    }
}

private struct ListView: View {
    let entry: BirthdayEntry
    let rows: Int

    var body: some View {
        if entry.birthdays.isEmpty {
            EmptyState(hasAccess: entry.hasAccess)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Label(NSLocalizedString("Next Birthdays", comment: "Birthday Buddy widget: title of the medium and large widget"), systemImage: "gift.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .widgetAccentable()
                    .padding(.bottom, 6)
                ForEach(entry.birthdays.prefix(rows)) { birthday in
                    HStack(spacing: 10) {
                        Avatar(birthday: birthday, size: 30)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(birthday.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            if let age = birthday.ageText(from: entry.date) {
                                Text(age)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 4)
                        let days = birthday.daysUntilNext(from: entry.date)
                        Text(birthday.whenText(from: entry.date))
                            .font(.caption.weight(days <= 7 ? .semibold : .regular))
                            .foregroundStyle(days <= 7 ? Color.red : Color.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxHeight: .infinity)
                }
                // Keeps a short list at the top instead of spreading it out.
                if entry.birthdays.count < rows { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct CircularView: View {
    let entry: BirthdayEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let next = entry.birthdays.first {
                let days = next.daysUntilNext(from: entry.date)
                VStack(spacing: 0) {
                    Image(systemName: "gift.fill").font(.caption)
                    if days == 0 {
                        Text("🎉").font(.title3)
                    } else {
                        Text("\(days)")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .minimumScaleFactor(0.6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(next.name), \(next.whenText(from: entry.date))")
            } else {
                Image(systemName: "gift")
            }
        }
    }
}

private struct RectangularView: View {
    let entry: BirthdayEntry

    var body: some View {
        if let next = entry.birthdays.first {
            VStack(alignment: .leading, spacing: 0) {
                Label(next.name, systemImage: "gift.fill")
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
                Text(next.whenText(from: entry.date))
                    .lineLimit(1)
                if let age = next.ageText(from: entry.date) {
                    Text(age)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label(entry.hasAccess
                  ? NSLocalizedString("No Birthdays", comment: "Birthday Buddy: title when no contact has a birthday")
                  : NSLocalizedString("Birthday Buddy", comment: "Menu item"),
                  systemImage: "gift")
        }
    }
}

private struct InlineView: View {
    let entry: BirthdayEntry

    var body: some View {
        if let next = entry.birthdays.first {
            Label("\(next.firstName) · \(next.whenText(from: entry.date))", systemImage: "gift.fill")
        } else {
            Label(NSLocalizedString("Birthday Buddy", comment: "Menu item"), systemImage: "gift")
        }
    }
}

struct BirthdayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BirthdayEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium: ListView(entry: entry, rows: 3)
            case .systemLarge: ListView(entry: entry, rows: 7)
            case .accessoryCircular: CircularView(entry: entry)
            case .accessoryRectangular: RectangularView(entry: entry)
            case .accessoryInline: InlineView(entry: entry)
            default: SmallView(entry: entry)
            }
        }
        .widgetURL(BirthdayBuddyURL)
    }
}

struct BirthdayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: BirthdayWidgetKind, provider: BirthdayProvider()) { entry in
            BirthdayWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(NSLocalizedString("Birthday Buddy", comment: "Menu item"))
        .description(NSLocalizedString("See whose birthday is next, on your Home Screen and Lock Screen.", comment: "Birthday Buddy widget: description in the widget gallery"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemMedium) {
    BirthdayWidget()
} timeline: {
    BirthdayEntry(date: .now, birthdays: BirthdayProvider.examples, hasAccess: true)
}
