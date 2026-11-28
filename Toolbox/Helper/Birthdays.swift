//
//  Birthdays.swift
//  Toolbox
//
//  The birthdays saved in the user's contacts. Shared by Birthday Buddy (app) and its widget
//  (diceWidgetExtension), which reads the contacts itself with the app's permission.
//

import Foundation
import Contacts

/// The kind of the Birthday Buddy widget, so the app can reload it.
let BirthdayWidgetKind = "BirthdayWidget"
/// Opens Birthday Buddy in the app (see `ContentView`'s `onOpenURL`).
let BirthdayBuddyURL = URL(string: "sivery-toolbox://tool/gift")!

struct Birthday: Identifiable, Hashable {
    /// The contact identifier, also used to mute a contact's reminders.
    let id: String
    let name: String
    let month: Int
    let day: Int
    /// Not every birthday is saved with a year.
    let year: Int?
    var thumbnail: Data?

    /// Birthdays are saved as Gregorian month and day, whatever calendar the device uses.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    /// The birthday in `year`. February 29 falls on February 28 in years that aren't leap years.
    func date(in year: Int) -> Date? {
        var day = day
        if month == 2 && day == 29 {
            let isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            if !isLeapYear { day = 28 }
        }
        return Self.calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// The next birthday on or after the day of `now`.
    func nextDate(from now: Date = .now) -> Date {
        let today = Self.calendar.startOfDay(for: now)
        let thisYear = Self.calendar.component(.year, from: today)
        for year in thisYear...(thisYear + 1) {
            if let date = date(in: year), date >= today { return date }
        }
        return today
    }

    func daysUntilNext(from now: Date = .now) -> Int {
        let today = Self.calendar.startOfDay(for: now)
        return Self.calendar.dateComponents([.day], from: today, to: nextDate(from: now)).day ?? 0
    }

    /// The age on the next birthday, when the year of birth is known.
    func ageOnNext(from now: Date = .now) -> Int? {
        guard let year else { return nil }
        return Self.calendar.component(.year, from: nextDate(from: now)) - year
    }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    // MARK: Contacts

    static var hasContactAccess: Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .authorized { return true }
        if #available(iOS 18.0, *) { return status == .limited }
        return false
    }

    /// Reads every contact that has a birthday. Without thumbnails it reads much less, which the
    /// widget needs to stay within its memory limit.
    static func fetchAll(thumbnails: Bool = true) throws -> [Birthday] {
        let store = CNContactStore()
        var keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
        ]
        if thumbnails { keys.append(CNContactThumbnailImageDataKey as CNKeyDescriptor) }
        let request = CNContactFetchRequest(keysToFetch: keys)
        var birthdays: [Birthday] = []
        try store.enumerateContacts(with: request) { contact, _ in
            guard let birthday = contact.birthday, let month = birthday.month, let day = birthday.day else { return }
            let formatted = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let name = formatted.isEmpty ? contact.organizationName : formatted
            // A contact without a year gets NSDateComponentUndefined, not nil.
            let year = birthday.year.flatMap { $0 == NSDateComponentUndefined ? nil : $0 }
            birthdays.append(Birthday(id: contact.identifier, name: name, month: month, day: day, year: year,
                                      thumbnail: thumbnails ? contact.thumbnailImageData : nil))
        }
        return birthdays
    }

    /// The thumbnails of a few contacts, for the birthdays the widget shows.
    static func thumbnails(for ids: [String]) -> [String: Data] {
        guard !ids.isEmpty else { return [:] }
        let request = CNContactFetchRequest(keysToFetch: [CNContactThumbnailImageDataKey as CNKeyDescriptor])
        request.predicate = CNContact.predicateForContacts(withIdentifiers: ids)
        var result: [String: Data] = [:]
        try? CNContactStore().enumerateContacts(with: request) { contact, _ in
            result[contact.identifier] = contact.thumbnailImageData
        }
        return result
    }

    /// Sorted by the next birthday after `now`, then by name.
    static func upcoming(_ birthdays: [Birthday], from now: Date = .now) -> [Birthday] {
        birthdays.sorted {
            let (a, b) = ($0.daysUntilNext(from: now), $1.daysUntilNext(from: now))
            return a == b ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : a < b
        }
    }

    /// "today", "tomorrow" or "in 5 days" in the user's language.
    static func relativeDays(_ days: Int) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter.localizedString(from: DateComponents(day: days))
    }
}
