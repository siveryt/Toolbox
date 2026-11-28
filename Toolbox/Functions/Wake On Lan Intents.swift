//
//  Wake On Lan Intents.swift
//  Toolbox
//
//  Siri, Shortcuts and Spotlight access to the saved Wake On Lan devices.
//

import AppIntents
import SwiftData

extension WOLDevice {
    /// The one container for the app and its App Intents.
    /// Uses the default store, so it opens the same data as the former `.modelContainer(for:)`.
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: WOLDevice.self)
        } catch {
            fatalError("Could not open the Wake On Lan devices: \(error)")
        }
    }()
}

// MARK: - Entity

/// A saved Wake On Lan device. Identified by its name, which SwiftData keeps unique.
struct WOLDeviceEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Wake On Lan Device", comment: "Shortcuts app: type name of a saved Wake On Lan device")
    )
    static let defaultQuery = WOLDeviceQuery()

    let id: String
    let mac: String

    init(_ device: WOLDevice) {
        id = device.name
        mac = device.mac
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(id)",
            subtitle: "\(mac)",
            image: .init(systemName: "desktopcomputer")
        )
    }
}

struct WOLDeviceQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [WOLDeviceEntity] {
        try devices().filter { identifiers.contains($0.name) }.map(WOLDeviceEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [WOLDeviceEntity] {
        try devices().filter { $0.name.localizedStandardContains(string) }.map(WOLDeviceEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [WOLDeviceEntity] {
        try devices().map(WOLDeviceEntity.init)
    }

    /// All saved devices, most recently used first (like the list in the app)
    @MainActor
    private func devices() throws -> [WOLDevice] {
        try WOLDevice.container.mainContext.fetch(FetchDescriptor<WOLDevice>(sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]))
    }
}

// MARK: - Intent

struct WakeDeviceIntent: AppIntent {
    static let title = LocalizedStringResource("Wake Device", comment: "Shortcuts app: title of the action that wakes a saved Wake On Lan device")
    static let description = IntentDescription(
        LocalizedStringResource("Sends a Wake On Lan magic packet to a device saved in Toolbox.", comment: "Shortcuts app: description of the Wake Device action"),
        categoryName: LocalizedStringResource("Wake On Lan", comment: "Shortcuts app: category of the Wake On Lan actions")
    )

    @Parameter(
        title: LocalizedStringResource("Device", comment: "Shortcuts app: parameter of the Wake Device action, the device to wake"),
        requestValueDialog: IntentDialog(LocalizedStringResource("Which device do you want to wake?", comment: "Siri: question when the user didn't say which Wake On Lan device to wake"))
    )
    var device: WOLDeviceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Wake \(\.$device)")
    }

    init() {}

    init(device: WOLDeviceEntity) {
        self.device = device
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = WOLDevice.container.mainContext
        let name = device.id
        let descriptor = FetchDescriptor<WOLDevice>(predicate: #Predicate { $0.name == name })
        guard let saved = try context.fetch(descriptor).first else {
            throw WakeIntentError.deviceNotFound(name)
        }
        try WakeOnLan.wake(saved)
        try? context.save()
        return .result(dialog: IntentDialog(LocalizedStringResource("Wake-up sent to \(name).", comment: "Siri: answer after the wake-up packet was sent, the placeholder is the device name")))
    }
}

enum WakeIntentError: Error, CustomLocalizedStringResourceConvertible {
    case deviceNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .deviceNotFound(let name):
            LocalizedStringResource("There is no saved device named \(name).", comment: "Siri and Shortcuts: error when the Wake On Lan device to wake was deleted or renamed, the placeholder is its name")
        }
    }
}

// MARK: - Siri

struct ToolboxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WakeDeviceIntent(),
            phrases: [
                "Wake \(\.$device) with \(.applicationName)",
                "Wake up \(\.$device) with \(.applicationName)",
                "Turn on \(\.$device) with \(.applicationName)",
                "Wake a device with \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("Wake Device", comment: "Shortcuts app: title of the action that wakes a saved Wake On Lan device"),
            systemImageName: "power"
        )
    }
}
