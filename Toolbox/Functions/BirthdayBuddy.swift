//
//  BirthdayBuddy.swift
//  Toolbox
//
//  Lists the birthdays saved in the user's contacts (the iOS Birthdays calendar is made from the
//  same data) and reminds the user a chosen number of days before each one.
//

import SwiftUI
import Contacts
import ContactsUI
import UserNotifications
import Haptica
import WidgetKit

// MARK: - Contacts and reminders

enum BirthdayReminders {
    static let enabledKey = "birthdayRemindersEnabled"
    static let daysBeforeKey = "birthdayReminderDaysBefore"
    /// Minutes after midnight.
    static let timeKey = "birthdayReminderTime"
    static let mutedKey = "birthdayMutedContacts"

    private static let identifierPrefix = "birthdayBuddy."
    /// iOS keeps only the 64 soonest local notifications of an app, so the app schedules the soonest
    /// ones and schedules again whenever it becomes active.
    private static let maximumScheduled = 60

    /// Replaces the scheduled birthday reminders with the soonest ones for the current settings.
    /// Does nothing to them when contacts or notifications aren't allowed, so they still fire.
    static func reschedule() async {
        let defaults = UserDefaults.standard
        let center = UNUserNotificationCenter.current()
        guard defaults.bool(forKey: enabledKey) else {
            await removeAll()
            return
        }
        guard Birthday.hasContactAccess else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        guard let birthdays = try? Birthday.fetchAll() else { return }

        let daysBefore = defaults.object(forKey: daysBeforeKey) as? Int ?? 1
        let minutes = defaults.object(forKey: timeKey) as? Int ?? 9 * 60
        let muted = Set([String](rawValue: defaults.string(forKey: mutedKey) ?? "[]") ?? [])
        let now = Date.now
        let calendar = Birthday.calendar

        var reminders: [(date: Date, birthday: Birthday, birthdayDate: Date)] = []
        for birthday in birthdays where !muted.contains(birthday.id) {
            let thisYear = calendar.component(.year, from: now)
            // The reminder for this year's birthday may already be over; then take next year's.
            for year in thisYear...(thisYear + 1) {
                guard let birthdayDate = birthday.date(in: year),
                      let day = calendar.date(byAdding: .day, value: -daysBefore, to: birthdayDate),
                      let date = calendar.date(byAdding: .minute, value: minutes, to: day) else { continue }
                if date > now {
                    reminders.append((date, birthday, birthdayDate))
                    break
                }
            }
        }
        reminders.sort { $0.date < $1.date }

        await removeAll()
        for reminder in reminders.prefix(maximumScheduled) {
            let content = UNMutableNotificationContent()
            content.title = reminder.birthday.name
            let age = reminder.birthday.year.map { calendar.component(.year, from: reminder.birthdayDate) - $0 }
            content.body = message(daysBefore: daysBefore, age: age)
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifierPrefix + reminder.birthday.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func removeAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func message(daysBefore: Int, age: Int?) -> String {
        if daysBefore == 0 {
            if let age {
                return String(format: NSLocalizedString("Turns %lld today 🎉", comment: "Birthday Buddy notification: body on the birthday, with the age the contact turns"), age)
            }
            return NSLocalizedString("Has a birthday today 🎉", comment: "Birthday Buddy notification: body on the birthday, when the year of birth isn't known")
        }
        let when = Birthday.relativeDays(daysBefore)
        if let age {
            return String(format: NSLocalizedString("Turns %1$lld %2$@", comment: "Birthday Buddy notification: body before the birthday. %1$lld is the age, %2$@ is when, e.g. \"in 3 days\" or \"tomorrow\""), age, when)
        }
        return String(format: NSLocalizedString("Birthday %@", comment: "Birthday Buddy notification: body before the birthday, when the year of birth isn't known. %@ is when, e.g. \"in 3 days\" or \"tomorrow\""), when)
    }
}

// MARK: - View

struct BirthdayBuddy: View {
    @AppStorage(BirthdayReminders.enabledKey) private var remindersEnabled = false
    @AppStorage(BirthdayReminders.daysBeforeKey) private var daysBefore = 1
    @AppStorage(BirthdayReminders.timeKey) private var reminderMinutes = 9 * 60
    @AppStorage(BirthdayReminders.mutedKey) private var muted: [String] = []

    @State private var contactStatus = CNContactStore.authorizationStatus(for: .contacts)
    @State private var birthdays: [Birthday] = []
    @State private var loaded = false
    @State private var searchText = ""
    @State private var notificationsDeniedAlert = false
    @State private var contactPickerPresented = false

    @Environment(\.openURL) private var openURL

    private var hasAccess: Bool { contactStatus == .authorized || contactStatus == .limited }

    var body: some View {
        Group {
            if hasAccess {
                birthdayList
            } else {
                accessView
            }
        }
        .navigationTitle("Birthday Buddy")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .CNContactStoreDidChange)) { _ in
            Task { await load() }
        }
        .alert("Notifications Are Off", isPresented: $notificationsDeniedAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Allow notifications for Toolbox in Settings to get birthday reminders.")
        }
    }

    // MARK: Access

    @ViewBuilder
    private var accessView: some View {
        if contactStatus == .notDetermined {
            ContentUnavailableView {
                Label("Never Miss a Birthday", systemImage: "gift")
            } description: {
                Text("Birthday Buddy shows the birthdays saved in your contacts and can remind you of them. Your contacts stay on your device.")
            } actions: {
                Button("Allow Access to Contacts") {
                    Task {
                        _ = try? await CNContactStore().requestAccess(for: .contacts)
                        await load()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView {
                Label("No Access to Contacts", systemImage: "person.crop.circle.badge.xmark")
            } description: {
                Text("Allow Toolbox to access your contacts in Settings to see their birthdays.")
            } actions: {
                Button("Open Settings") { openSettings() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: List

    private var filtered: [Birthday] {
        let sorted = Birthday.upcoming(birthdays)
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedStandardContains(searchText) }
    }

    /// Today's birthdays first, then the others grouped by the month of their next birthday.
    private var sections: [(title: String, birthdays: [Birthday])] {
        var result: [(title: String, birthdays: [Birthday])] = []
        let today = filtered.filter { $0.daysUntilNext() == 0 }
        if !today.isEmpty {
            result.append((NSLocalizedString("Today", comment: "Birthday Buddy: section header for the birthdays that are today"), today))
        }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        for birthday in filtered where birthday.daysUntilNext() > 0 {
            let title = formatter.string(from: birthday.nextDate())
            if result.last?.title == title {
                result[result.count - 1].birthdays.append(birthday)
            } else {
                result.append((title, [birthday]))
            }
        }
        return result
    }

    private var birthdayList: some View {
        List {
            Section {
                Toggle("Reminders", isOn: Binding(get: { remindersEnabled }, set: setReminders))
                if remindersEnabled {
                    Stepper(value: $daysBefore, in: 0...30) {
                        LabeledContent("Remind Me", value: daysBeforeText)
                    }
                    DatePicker("Reminder Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
            } footer: {
                if remindersEnabled {
                    Text("Swipe a birthday to mute its reminder.")
                }
            }

            if contactStatus == .limited {
                Section {
                    Button("Choose Contacts…") { contactPickerPresented = true }
                } footer: {
                    Text("Toolbox can only see the contacts you shared with it.")
                }
            }

            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.birthdays) { birthday in
                        BirthdayRow(birthday: birthday, muted: remindersEnabled && muted.contains(birthday.id))
                            .swipeActions(edge: .trailing) {
                                if remindersEnabled { muteButton(birthday) }
                            }
                            .contextMenu {
                                if remindersEnabled { muteButton(birthday) }
                            }
                    }
                }
            }
        }
        .animation(.default, value: remindersEnabled)
        .searchable(text: $searchText)
        .refreshable { await load() }
        .overlay {
            if loaded && birthdays.isEmpty {
                ContentUnavailableView {
                    Label("No Birthdays", systemImage: "gift")
                } description: {
                    Text("Add a birthday to a contact in the Contacts app and it shows up here.")
                }
            } else if !searchText.isEmpty && filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .contactAccessPicker(isPresented: $contactPickerPresented) { _ in
            Task { await load() }
        }
        .onChange(of: daysBefore) { Task { await BirthdayReminders.reschedule() } }
        .onChange(of: reminderMinutes) { Task { await BirthdayReminders.reschedule() } }
        .onChange(of: muted) { Task { await BirthdayReminders.reschedule() } }
    }

    private func muteButton(_ birthday: Birthday) -> some View {
        let isMuted = muted.contains(birthday.id)
        return Button {
            Haptic.impact(.light).generate()
            if isMuted {
                muted.removeAll { $0 == birthday.id }
            } else {
                muted.append(birthday.id)
            }
        } label: {
            if isMuted {
                Label("Unmute Reminder", systemImage: "bell")
            } else {
                Label("Mute Reminder", systemImage: "bell.slash")
            }
        }
        .tint(isMuted ? .accentColor : .gray)
    }

    private var daysBeforeText: String {
        if daysBefore == 0 {
            return NSLocalizedString("On the Day", comment: "Birthday Buddy settings: remind on the birthday itself")
        }
        return String.localizedStringWithFormat(NSLocalizedString("%lld days before", comment: "Birthday Buddy settings: how many days before the birthday the reminder comes"), daysBefore)
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinutes = (components.hour ?? 9) * 60 + (components.minute ?? 0)
        }
    }

    // MARK: Actions

    private func load() async {
        contactStatus = CNContactStore.authorizationStatus(for: .contacts)
        guard hasAccess else { return }
        // Reading many contacts takes a moment, so do it off the main thread.
        let result = await Task.detached { (try? Birthday.fetchAll()) ?? [] }.value
        birthdays = result
        loaded = true
        // The widget reads the contacts itself; this makes it show changes (or the new access) right away.
        WidgetCenter.shared.reloadTimelines(ofKind: BirthdayWidgetKind)
        await BirthdayReminders.reschedule()
    }

    private func setReminders(_ on: Bool) {
        guard on else {
            remindersEnabled = false
            Task { await BirthdayReminders.reschedule() }
            return
        }
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                remindersEnabled = true
                await BirthdayReminders.reschedule()
            } else {
                notificationsDeniedAlert = true
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

// MARK: - Row

private struct BirthdayRow: View {
    let birthday: Birthday
    let muted: Bool

    private var dateText: String {
        let formatter = DateFormatter()
        if let year = birthday.year, let date = birthday.date(in: year) {
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter.string(from: birthday.nextDate())
    }

    var body: some View {
        let days = birthday.daysUntilNext()
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(birthday.name)
                    if muted {
                        Image(systemName: "bell.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Reminder muted")
                    }
                }
                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if days == 0 {
                    Text("Today 🎉")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text(Birthday.relativeDays(days))
                        .monospacedDigit()
                        .foregroundStyle(days <= 7 ? Color.accentColor : .primary)
                }
                if let age = birthday.ageOnNext() {
                    Text(String(format: NSLocalizedString("turns %lld", comment: "Birthday Buddy list: the age the contact turns on their next birthday"), age))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = birthday.thumbnail, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            Text(birthday.initials)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.accentColor.gradient))
        }
    }
}

#Preview {
    NavigationStack {
        BirthdayBuddy()
    }
}
