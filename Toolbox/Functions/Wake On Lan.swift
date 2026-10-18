//
//  Wake On Lan.swift
//  Toolbox
//
//  Created by Christian Nagel on 21.05.24.
//

import SwiftUI
import SwiftData

struct Wake_On_Lan: View {
    enum Field: CaseIterable {
        case name, mac, broadcast, port
    }

    @Environment(\.modelContext) var modelContext
    @Query(sort: \WOLDevice.lastUsed, order: .reverse) var devices: [WOLDevice]

    @State var pendingDevice: WOLDevice? = nil
    @State var wakeAlertPresented = false
    @State var wakeErrorMessage = ""
    @State var wakeErrorPresented = false
    @State var sheetDisplayed = false
    @State var editing = false

    /// Fields the user already interacted with. Validation errors are only shown for these,
    /// so an empty form doesn't greet the user with a wall of red text.
    @State var touchedFields: Set<Field> = []

    @State var sheet_name = ""
    @State var sheet_mac = ""
    @State var sheet_broadcast = ""
    @State var sheet_port = "9"
    @State var sheet_editDevice: WOLDevice? = nil

    var body: some View {
        List {
            ForEach(devices) { device in
                Button(device.name, action: {
                    pendingDevice = device
                    wakeAlertPresented = true
                })
                .tint(.primary)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        wake(device)
                    } label: {
                        Text("Wake")
                    }
                    .tint(.accentColor)
                }

                .contextMenu {
                    Button(action:{
                        sheet_name = device.name
                        sheet_mac = device.mac
                        sheet_broadcast = device.broadcast
                        sheet_port = String(device.port ?? 9)
                        sheet_editDevice = device
                        editing = true
                        // Existing data may already be invalid (saved by an older version) – show why right away
                        touchedFields = Set(Field.allCases)
                        sheetDisplayed = true
                    }){
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action:{
                        withAnimation(){
                            modelContext.delete(device)
                        }
                    }){
                        Label(NSLocalizedString("Delete", comment: "Generic delete action: Info screen button that deletes all app data, Wake On Lan context menu that deletes a device, and the backspace key of the Apple Watch Roman Numbers keypad"), systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }

            }
            .onDelete(perform: delete)
        }
        .overlay {
            if devices.isEmpty {
                ContentUnavailableView {
                    Label("No Devices", systemImage: "power")
                } description: {
                    Text("Tap + to add a device you want to wake up.")
                }
            }
        }
        .sheet(isPresented: $sheetDisplayed, onDismiss: resetSheetData, content: {
            WOLDeviceForm(
                name: $sheet_name,
                mac: $sheet_mac,
                broadcast: $sheet_broadcast,
                port: $sheet_port,
                touchedFields: $touchedFields,
                nameError: nameError,
                macError: macError,
                broadcastError: broadcastError,
                portError: portError,
                formIsValid: formIsValid,
                isEditing: editing,
                onSave: save
            )
        })
        .navigationTitle("Wake On Lan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(action: {
                resetSheetData()
                sheetDisplayed = true
            }, label: {
                Image(systemName: "plus")
            })
        }
        .alert("Are you sure you want to start the device?", isPresented: $wakeAlertPresented, presenting: pendingDevice) { device in
            Button("Cancel", role: .cancel) { }
            Button("Yes") {
                wake(device)
            }
        }
        .alert("Couldn't wake the device", isPresented: $wakeErrorPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(wakeErrorMessage)
        }
    }

    // MARK: - Validation

    var trimmedName: String { sheet_name.trimmingCharacters(in: .whitespaces) }
    var trimmedBroadcast: String { sheet_broadcast.trimmingCharacters(in: .whitespaces) }

    var nameError: LocalizedStringKey? {
        if trimmedName.isEmpty {
            return "You can't leave the name empty"
        }
        // The name is @Attribute(.unique) – a duplicate would silently overwrite the other device
        if devices.contains(where: { $0.name == trimmedName && $0.persistentModelID != sheet_editDevice?.persistentModelID }) {
            return "You can't use the same name twice"
        }
        return nil
    }

    var macError: LocalizedStringKey? {
        if sheet_mac.trimmingCharacters(in: .whitespaces).isEmpty {
            return "You can't leave the MAC empty"
        }
        if WakeOnLan.parseMAC(sheet_mac) == nil {
            return "Enter a valid MAC address, e.g. 00:1A:2B:3C:4D:5E"
        }
        return nil
    }

    var broadcastError: LocalizedStringKey? {
        if trimmedBroadcast.isEmpty {
            return "You can't leave the Broadcast empty"
        }
        if WakeOnLan.parseIPv4(trimmedBroadcast) == nil {
            return "Enter a valid IPv4 address, e.g. 192.168.1.255"
        }
        return nil
    }

    var portError: LocalizedStringKey? {
        if sheet_port.isEmpty {
            return "You can't leave the port empty"
        }
        if WakeOnLan.parsePort(sheet_port) == nil {
            return "Enter a port between 1 and 65535"
        }
        return nil
    }

    var formIsValid: Bool {
        nameError == nil && macError == nil && broadcastError == nil && portError == nil
    }

    // MARK: - Actions

    func save() {
        guard formIsValid,
              let mac = WakeOnLan.parseMAC(sheet_mac),
              let port = WakeOnLan.parsePort(sheet_port) else { return }
        let formattedMAC = WakeOnLan.format(mac: mac)

        if editing, let device = sheet_editDevice {
            device.name = trimmedName
            device.mac = formattedMAC
            device.broadcast = trimmedBroadcast
            device.port = Int(port)
        } else {
            modelContext.insert(WOLDevice(name: trimmedName, mac: formattedMAC, broadcast: trimmedBroadcast, port: Int(port)))
        }
        sheetDisplayed = false
    }

    func delete(_ indexSet: IndexSet) {
        for index in indexSet {
            let device = devices[index]
            modelContext.delete(device)
        }
    }

    func wake(_ device: WOLDevice) {
        do {
            // Stored data is re-validated here: entries saved by older versions were never checked
            guard let mac = WakeOnLan.parseMAC(device.mac) else {
                throw WakeOnLan.WakeError.invalidMAC(device.mac)
            }
            guard let address = WakeOnLan.parseIPv4(device.broadcast) else {
                throw WakeOnLan.WakeError.invalidBroadcast(device.broadcast)
            }
            guard let port = WakeOnLan.parsePort(String(device.port ?? 9)) else {
                throw WakeOnLan.WakeError.invalidPort(device.port ?? 9)
            }
            try WakeOnLan.sendMagicPacket(mac: mac, to: address, port: port)
            withAnimation {
                device.lastUsed = Date()
            }
        } catch {
            wakeErrorMessage = error.localizedDescription
            wakeErrorPresented = true
        }
    }

    func resetSheetData() {
        editing = false
        touchedFields = []

        sheet_name = ""
        sheet_mac = ""
        sheet_broadcast = getBroadcast() ?? ""
        sheet_port = "9"
        sheet_editDevice = nil
    }

    func getBroadcast() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            // Look for the main interface, commonly 'en0' for Wi-Fi.
            // ifa_addr / ifa_netmask can be NULL for some interfaces, so they must be unwrapped.
            guard String(cString: interface.pointee.ifa_name) == "en0",
                  let addr = interface.pointee.ifa_addr,
                  let netmask = interface.pointee.ifa_netmask,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            // Check for running, non-loopback interfaces
            let flags = Int32(interface.pointee.ifa_flags)
            guard (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) else { continue }

            let ip4Address = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            let netmaskAddress = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }

            // Calculate broadcast address
            var broadcastAddr = in_addr(s_addr: ip4Address | ~netmaskAddress)
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &broadcastAddr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
            return String(cString: buffer)
        }

        return nil
    }
}

/// The add/edit form shown in a sheet.
///
/// Lives in its own view because `@FocusState` owned by the presenting view doesn't reach
/// into sheet content – moving focus from one field to the next silently did nothing.
struct WOLDeviceForm: View {
    typealias Field = Wake_On_Lan.Field

    @Binding var name: String
    @Binding var mac: String
    @Binding var broadcast: String
    @Binding var port: String
    @Binding var touchedFields: Set<Field>

    let nameError: LocalizedStringKey?
    let macError: LocalizedStringKey?
    let broadcastError: LocalizedStringKey?
    let portError: LocalizedStringKey?
    let formIsValid: Bool
    let isEditing: Bool
    let onSave: () -> Void

    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss
    /// The values the sheet opened with, to tell whether there is anything to lose on cancel.
    @State private var initialValues: [String]?
    @State private var confirmingDiscard = false

    private var hasChanges: Bool {
        initialValues.map { $0 != [name, mac, broadcast, port] } ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack {
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("Device Name", text: $name)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .mac }
                        }
                        errorLabel(nameError, for: .name)
                    }
                    VStack {
                        HStack {
                            Text(NSLocalizedString("MAC", comment: "Wake On Lan form: label of the MAC address field of the device to wake"))
                            Spacer()
                            TextField("00:1A:2B:3C:4D:5E", text: $mac)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .mac)
                                .keyboardType(.asciiCapable)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .onSubmit { focusedField = .broadcast }
                        }
                        errorLabel(macError, for: .mac)
                    }
                    VStack {
                        HStack {
                            Text("Broadcast")
                            Spacer()
                            TextField("255.255.255.255", text: $broadcast)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .broadcast)
                                .keyboardType(.numbersAndPunctuation)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .onSubmit { focusedField = .port }
                        }
                        errorLabel(broadcastError, for: .broadcast)
                    }
                    VStack {
                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("9", text: $port)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .port)
                                .keyboardType(.numberPad)
                        }
                        errorLabel(portError, for: .port)
                    }
                }
            }
            .onChange(of: name) { touchedFields.insert(.name) }
            .onChange(of: mac) { touchedFields.insert(.mac) }
            .onChange(of: broadcast) { touchedFields.insert(.broadcast) }
            .onChange(of: port) { _, newValue in
                let filtered = newValue.filter { "0123456789".contains($0) }
                if filtered != newValue {
                    port = filtered
                }
                touchedFields.insert(.port)
            }
            .onChange(of: focusedField) { oldValue, _ in
                // Leaving a field counts as touching it, so skipped required fields get flagged
                if let oldValue {
                    touchedFields.insert(oldValue)
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UITextField.textDidBeginEditingNotification)) { _ in
                    DispatchQueue.main.async {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                        )
                    }
                }
            .navigationTitle(isEditing
                             ? NSLocalizedString("Edit Device", comment: "Wake On Lan: title of the sheet to edit an existing device")
                             : NSLocalizedString("Add new Device", comment: "Wake On Lan: title of the sheet to add a new device"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if initialValues == nil { initialValues = [name, mac, broadcast, port] }
            }
            // swiping away would lose the input, so that only works without changes
            .interactiveDismissDisabled(hasChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        if hasChanges {
                            confirmingDiscard = true
                        } else {
                            dismiss()
                        }
                    }
                    .confirmationDialog("Discard Changes", isPresented: $confirmingDiscard) {
                        Button("Discard Changes", role: .destructive) { dismiss() }
                        Button("Keep Editing", role: .cancel) { }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        onSave()
                    }
                    .disabled(!formIsValid)
                }
                // The number pad has no return key, so the port field gets its own way to finish
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .port {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func errorLabel(_ message: LocalizedStringKey?, for field: Field) -> some View {
        if let message, touchedFields.contains(field) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Minimal, crash-safe Wake-on-LAN implementation.
///
/// Replaces the `Awake` package, which crashes on input it can't parse:
/// it force-converts every MAC component into a byte (trap on e.g. "001A2B3C4D5E")
/// and passes the result of a failed `gethostbyname` (NULL) straight into `inet_addr`.
enum WakeOnLan {
    enum WakeError: LocalizedError {
        case invalidMAC(String)
        case invalidBroadcast(String)
        case invalidPort(Int)
        case socketFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidMAC(let mac):
                return String(format: NSLocalizedString("The MAC address \"%@\" is invalid. Edit the device to fix it.", comment: "Wake On Lan: error when waking a saved device, %@ is its MAC address"), mac)
            case .invalidBroadcast(let broadcast):
                return String(format: NSLocalizedString("The broadcast address \"%@\" is invalid. Edit the device to fix it.", comment: "Wake On Lan: error when waking a saved device, %@ is its broadcast IP address"), broadcast)
            case .invalidPort(let port):
                return String(format: NSLocalizedString("The port %lld is invalid. Edit the device to fix it.", comment: "Wake On Lan: error when waking a saved device, %lld is its port number"), port)
            case .socketFailed(let reason):
                return String(format: NSLocalizedString("The magic packet could not be sent: %@", comment: "Wake On Lan: error when sending the wake signal failed, %@ is the system's reason (e.g. \"No route to host\")"), reason)
                    + "\n\n"
                    + NSLocalizedString("Check that Toolbox can access your local network in Settings.", comment: "Wake On Lan: hint below the error when sending the wake signal failed (Local Network permission)")
            }
        }
    }

    /// Accepts "00:1A:2B:3C:4D:5E", "00-1A-2B-3C-4D-5E", "001A.2B3C.4D5E" and "001A2B3C4D5E".
    static func parseMAC(_ string: String) -> [UInt8]? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        // Separators must group the digits consistently, otherwise "123:1A:…" would be silently re-grouped
        var groups = [Substring(trimmed)]
        for (separator, count) in [(Character(":"), 6), ("-", 6), (".", 3)] {
            let parts = trimmed.split(separator: separator, omittingEmptySubsequences: false)
            if parts.count == count {
                groups = parts
                break
            }
        }
        guard groups.allSatisfy({ $0.count == 12 / groups.count }) else { return nil }
        let hex = groups.joined()
        // UInt8(_:radix:) alone would also accept a sign, e.g. "+F"
        guard hex.count == 12, hex.allSatisfy({ "0123456789abcdefABCDEF".contains($0) }) else { return nil }

        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    static func format(mac: [UInt8]) -> String {
        mac.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    static func parseIPv4(_ string: String) -> in_addr? {
        var address = in_addr()
        guard inet_pton(AF_INET, string.trimmingCharacters(in: .whitespaces), &address) == 1 else { return nil }
        return address
    }

    static func parsePort(_ string: String) -> UInt16? {
        guard let port = UInt16(string), port > 0 else { return nil }
        return port
    }

    static func sendMagicPacket(mac: [UInt8], to address: in_addr, port: UInt16) throws {
        // 6 × 0xFF followed by the MAC address repeated 16 times
        let packet = [UInt8](repeating: 0xFF, count: 6) + Array(repeatElement(mac, count: 16).joined())

        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { throw WakeError.socketFailed(String(cString: strerror(errno))) }
        defer { close(sock) }

        var broadcast: Int32 = 1
        guard setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            throw WakeError.socketFailed(String(cString: strerror(errno)))
        }

        var target = sockaddr_in()
        target.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        target.sin_family = sa_family_t(AF_INET)
        target.sin_port = port.bigEndian
        target.sin_addr = address

        let sent = withUnsafePointer(to: &target) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(sock, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard sent == packet.count else { throw WakeError.socketFailed(String(cString: strerror(errno))) }
    }
}

#Preview {
    NavigationStack {
        Wake_On_Lan()
    }
    .modelContainer(for: WOLDevice.self, inMemory: true)
}
