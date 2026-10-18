//
//  FontInstall.swift
//  Toolbox
//
//  Created by Christian Nagel on 01.05.24.
//

import SwiftUI
import UniformTypeIdentifiers
import Swifter
import SafariServices

struct FontInstall: View {
    @State private var isShowingSafari = false
    @State private var serverURL: URL? = nil
    @State private var isFilePickerPresented = false
    @State private var fontName: String? = nil
    @State private var fontValidationMessage: String = ""
    @State private var isValidFont: Bool = false
    @State private var showingInstructions = false
    @State private var showingCollectionWarning = false
    /// The configuration profile for the selected font, built when the font is selected.
    @State private var profileData: Data? = nil
    // Kept in @State so the running server survives when SwiftUI recreates this view.
    @State private var server = HttpServer()

    private static let profilePath = "/font-profile.mobileconfig"

    var body: some View {
        List {
            Section("Font Selection") {
                Button("Select Font File") {
                    isFilePickerPresented = true
                }
                .fileImporter(
                    isPresented: $isFilePickerPresented,
                    allowedContentTypes: [.font, .data],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        validateAndSetFont(url: url)
                    case .failure(let error):
                        fail(String(format: NSLocalizedString("The file could not be selected: %@", comment: "Font Installer: error when the file picker failed, %@ is the system's error message"), error.localizedDescription))
                    }
                }

                Text(String(format: NSLocalizedString("Font selected: %@", comment: "Font Installer: name of the chosen font file"),
                            fontName ?? NSLocalizedString("None", comment: "Font Installer: shown when no font is chosen yet")))

                if !fontValidationMessage.isEmpty {
                    Text(fontValidationMessage)
                        .foregroundColor(isValidFont ? .green : .red)
                        .font(.caption)
                }
            }

            Section("Installation") {
                Button("Install Font") {
                    installFont()
                }
                .disabled(!isValidFont)

                Button("Show Installation Instructions") {
                    showingInstructions = true
                }
            }
        }
        .sheet(isPresented: $isShowingSafari, onDismiss: {
            // The user closed Safari, so the profile was downloaded (or not): show what to do next.
            showingInstructions = true
        }) {
            if let url = serverURL, url.scheme == "http" || url.scheme == "https" {
                SafariView(url: url) {
                    isShowingSafari = false
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .sheet(isPresented: $showingInstructions) {
            NavigationStack {
                InstallationInstructionsView()
                    .navigationTitle("Installation Guide")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        Button(role: .close) {
                            showingInstructions = false
                        }
                    }
            }
        }
        .alert("Font Collection Not Supported", isPresented: $showingCollectionWarning) {
            Button("OK") { }
        } message: {
            Text("iOS does not support font collections (.ttc/.otc files). Please use individual font files (.ttf/.otf) instead. Font collections contain multiple fonts in one file, but iOS can only install single fonts through configuration profiles.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Font Installer")
        .onDisappear {
            server.stop()
        }
    }

    /// Shows an error message and forgets the selected font.
    private func fail(_ message: String) {
        fontValidationMessage = message
        isValidFont = false
        fontName = nil
        profileData = nil
        serverURL = nil
    }

    func validateAndSetFont(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            fail(NSLocalizedString("Unable to access the selected file.", comment: "Font Installer: error when the app may not read the chosen file"))
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent

        // Check if it's a font collection first
        if fileExtension == "ttc" || fileExtension == "otc" {
            fail(NSLocalizedString("Font collections (.ttc/.otc) are not supported by iOS.", comment: "Font Installer: error when a font collection file was chosen"))
            showingCollectionWarning = true
            return
        }

        // Check file extension for supported single font formats
        let supportedExtensions = ["ttf", "otf"]
        guard supportedExtensions.contains(fileExtension) else {
            fail(NSLocalizedString("Unsupported file type. Please select a TrueType (.ttf) or OpenType (.otf) font file.", comment: "Font Installer: error when the chosen file is not a .ttf or .otf file"))
            return
        }

        // Validate font data
        guard let fontData = try? Data(contentsOf: url), fontData.count > 0 else {
            fail(NSLocalizedString("Unable to read the font file, or the file is empty.", comment: "Font Installer: error when the chosen font file can't be read"))
            return
        }

        // Basic font file signature validation
        switch validateFontSignature(data: fontData) {
        case .valid:
            guard let profile = fontProfileData(fontData: fontData, fontName: url.deletingPathExtension().lastPathComponent) else {
                fail(NSLocalizedString("The installation profile for this font could not be created.", comment: "Font Installer: error when the configuration profile could not be built"))
                return
            }
            profileData = profile
            serverURL = nil
            fontName = fileName
            fontValidationMessage = "✓ " + String(format: NSLocalizedString("Valid %@ font file", comment: "Font Installer: shown when the chosen file is a valid font, %@ is the file type, e.g. TTF"), fileExtension.uppercased())
            isValidFont = true

        case .collection:
            fail(NSLocalizedString("This file appears to be a font collection, which is not supported by iOS.", comment: "Font Installer: error when the chosen file contains a font collection"))
            showingCollectionWarning = true

        case .invalid:
            fail(NSLocalizedString("Invalid font file. The file doesn't appear to be a valid font.", comment: "Font Installer: error when the chosen file is not a font"))
        }
    }

    enum FontValidationResult {
        case valid
        case collection
        case invalid
    }

    /// Checks the first four bytes of the file. The extension says nothing about the outlines:
    /// .ttf files can contain CFF outlines and .otf files TrueType outlines, so both are accepted for both.
    func validateFontSignature(data: Data) -> FontValidationResult {
        guard data.count >= 4 else { return .invalid }

        let signature = Array(data.prefix(4))

        // Font collections
        if signature == Array("ttcf".utf8) {
            return .collection
        }

        // TrueType outlines (0x00010000, or "true" for old Apple fonts) and CFF outlines ("OTTO")
        if signature == [0x00, 0x01, 0x00, 0x00] ||
           signature == Array("true".utf8) ||
           signature == Array("OTTO".utf8) {
            return .valid
        }

        return .invalid
    }

    /// Starts the local server (reachable from this device only) and opens the profile in Safari.
    func installFont() {
        guard let profileData else { return }

        server[Self.profilePath] = { _ in
            HttpResponse.raw(200, "OK", [
                "Content-Type": "application/x-apple-aspen-config",
                "Cache-Control": "no-store"
            ]) { writer in
                try writer.write(profileData)
            }
        }

        do {
            if !server.operating {
                // Listen on the loopback address only, so the profile is not reachable from the network,
                // on a port the system picks, so a busy port can't break the installation.
                server.listenAddressIPv4 = "127.0.0.1"
                try server.start(0, forceIPv4: true)
            }
            let port = try server.port()
            // The query makes every installation a new URL, so Safari never shows a cached profile.
            guard let url = URL(string: "http://127.0.0.1:\(port)\(Self.profilePath)?id=\(UUID().uuidString)") else {
                throw URLError(.badURL)
            }
            serverURL = url
            isShowingSafari = true
        } catch {
            server.stop()
            serverURL = nil
            isValidFont = false
            fontValidationMessage = String(format: NSLocalizedString("The installation could not be started: %@", comment: "Font Installer: error when the local server for the profile could not start, %@ is the system's error message"), error.localizedDescription)
        }
    }

    /// Builds the configuration profile that installs the font.
    func fontProfileData(fontData: Data, fontName: String) -> Data? {
        let fontPayload: [String: Any] = [
            "Name": fontName,
            "Font": fontData,
            "PayloadIdentifier": "de.sivery.Toolbox.font.\(UUID().uuidString)",
            "PayloadType": "com.apple.font",
            "PayloadUUID": UUID().uuidString,
            "PayloadVersion": 1,
            "PayloadDisplayName": fontName
        ]

        let profile: [String: Any] = [
            "PayloadContent": [fontPayload],
            "PayloadDisplayName": fontName,
            "PayloadIdentifier": "de.sivery.Toolbox.fontinstallation.\(UUID().uuidString)",
            "PayloadRemovalDisallowed": false,
            "PayloadType": "Configuration",
            "PayloadUUID": UUID().uuidString,
            "PayloadVersion": 1,
            "PayloadDescription": String(format: NSLocalizedString("Installs the font \"%@\".", comment: "Font Installer: description of the configuration profile, shown in Settings when installing it, %@ is the font name"), fontName)
        ]

        return try? PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
    }
}

struct InstallationInstructionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("How to Install Fonts on iOS")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("After downloading the configuration profile, follow these steps to complete the font installation:")
                        .font(.body)
                }

                Group {
                    Text("Step 1: Install the Profile")
                        .font(.headline)

                    Text("• The configuration profile should automatically open in Safari")
                    Text("• Tap 'Install' when prompted")
                    Text("• Enter your device passcode if requested")
                    Text("• Tap 'Install' again to confirm")
                }

                Group {
                    Text("Step 2: Enable the Profile in Settings")
                        .font(.headline)

                    Text("1. Open the Settings app")
                    Text("2. Navigate to: General → VPN & Device Management")
                    Text("3. Under 'Downloaded Profile', find your font profile")
                    Text("4. Tap on the profile and then tap 'Install'")
                    Text("5. Enter your passcode when prompted")
                    Text("6. Tap 'Install' to confirm")
                }

                Group {
                    Text("Step 3: Verify Installation")
                        .font(.headline)

                    Text("1. Go to Settings → General → Fonts")
                    Text("2. Your installed font should appear in the list")
                    Text("3. The font is now available in compatible apps")
                }

                Group {
                    Text("Supported Font Formats")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Text("✓ TrueType (.ttf) - Recommended")
                    Text("✓ OpenType (.otf) - Recommended")
                    Text("✗ TrueType Collection (.ttc) - Not supported")
                    Text("✗ OpenType Collection (.otc) - Not supported")

                    Text("Note: Font collections contain multiple fonts in one file, but iOS can only install individual fonts through configuration profiles.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Group {
                    Text("Important Notes")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Text("• Some apps may require a restart to recognize new fonts")
                    Text("• Not all apps support custom fonts")
                    Text("• To remove a font, go to Settings → General → Fonts and swipe left on the font name")
                    Text("• Font collections (.ttc/.otc) are not supported by iOS")
                }
            }
            .padding()
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    /// Called when the user taps Done.
    var onFinish: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.modalPresentationStyle = .fullScreen
        safariViewController.delegate = context.coordinator
        return safariViewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        context.coordinator.onFinish = onFinish
    }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var onFinish: (() -> Void)?

        init(onFinish: (() -> Void)?) {
            self.onFinish = onFinish
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onFinish?()
        }
    }
}
