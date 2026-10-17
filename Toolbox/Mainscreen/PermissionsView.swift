//
//  PermissionsView.swift
//  Toolbox
//

import SwiftUI
import AVFoundation
import CoreLocation

/// Settings page that lists every permission Toolbox can ask for, its current state and why it's needed.
struct permissions: View {
    @StateObject private var locationManager = LocationPermsChecker()
    @State private var camera = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            PermissionRow(
                title: NSLocalizedString("Location", comment: "Permission name"),
                symbol: "location.fill",
                color: .blue,
                status: Self.title(for: locationManager.authorizationStatus),
                reason: NSLocalizedString("To show your coordinates and speed and to measure distances.", comment: "Permission reason"),
                tools: ["Coordinates", "Distance", "Speed"]
            )
            PermissionRow(
                title: NSLocalizedString("Camera", comment: "Permission name"),
                symbol: "camera.fill",
                color: .gray,
                status: Self.title(for: camera),
                reason: NSLocalizedString("To scan barcodes and to show scrolling text on the back display.", comment: "Permission reason"),
                tools: ["Barcode Scanner", "Scrolling Text"]
            )
            PermissionRow(
                title: NSLocalizedString("Microphone", comment: "Permission name"),
                symbol: "mic.fill",
                color: .orange,
                status: Self.title(for: microphone),
                reason: NSLocalizedString("To measure the sound level around you.", comment: "Permission reason"),
                tools: ["Decibel Meter"]
            )
            // iOS doesn't tell apps whether local network access was granted, so there is no status
            PermissionRow(
                title: NSLocalizedString("Local Network", comment: "Permission name"),
                symbol: "network",
                color: .green,
                status: nil,
                reason: NSLocalizedString("To find devices on your network and to wake them up.", comment: "Permission reason"),
                tools: ["LAN Scanner", "Wake On Lan"]
            )

            Section {
                Button("Change in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, phase in
            // the user may have changed something in Settings
            if phase == .active {
                camera = AVCaptureDevice.authorizationStatus(for: .video)
                microphone = AVCaptureDevice.authorizationStatus(for: .audio)
            }
        }
    }

    private static func title(for status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: NSLocalizedString("Allowed", comment: "Permission state")
        case .notDetermined: NSLocalizedString("Not Requested Yet", comment: "Permission state: the app hasn't asked yet")
        case .denied, .restricted: NSLocalizedString("Denied", comment: "Permission state")
        @unknown default: NSLocalizedString("Unknown", comment: "Permission state")
        }
    }

    private static func title(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways: NSLocalizedString("Always", comment: "Location permission state")
        case .authorizedWhenInUse: NSLocalizedString("While Using", comment: "Location permission state: only while the app is in use")
        case .denied: NSLocalizedString("Denied", comment: "Permission state")
        case .restricted: NSLocalizedString("Restricted", comment: "Permission state: blocked, e.g. by Screen Time")
        case .notDetermined: NSLocalizedString("Not Requested Yet", comment: "Permission state: the app hasn't asked yet")
        @unknown default: NSLocalizedString("Unknown", comment: "Permission state")
        }
    }
}

/// One permission as its own section: icon, name and state, with the reason in the footer.
struct PermissionRow: View {
    let title: String
    let symbol: String
    let color: Color
    let status: String?
    let reason: String
    /// Menu titles of the tools that use this permission.
    let tools: [String]

    var body: some View {
        Section {
            LabeledContent {
                if let status { Text(status) }
            } label: {
                Label {
                    Text(title)
                } icon: {
                    // the colored squares of the Settings app
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 29, height: 29)
                        .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
        } footer: {
            Text(reason + " " + String(format: NSLocalizedString("Used by %@.", comment: "Permission footer, followed by a list of tools"),
                                       ListFormatter.localizedString(byJoining: tools.map { NSLocalizedString($0, comment: "Menu item") })))
        }
    }
}

class LocationPermsChecker: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        self.manager.delegate = self
        // No need to request authorization here
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
    }
}

struct permissions_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { permissions() }
    }
}
