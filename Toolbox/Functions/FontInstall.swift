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
    @State private var serverURL = URL(string: "about:blank")
    @State private var isFilePickerPresented = false
    @State private var fontName: String? = nil
    @State private var fontValidationMessage: String = ""
    @State private var isValidFont: Bool = false
    @State private var showingInstructions = false
    @State private var showingCollectionWarning = false
    private let server = HttpServer()

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
                        fontValidationMessage = "Error selecting file: \(error.localizedDescription)"
                        isValidFont = false
                    }
                }

                Text("Font selected: " + (fontName ?? "None"))

                if !fontValidationMessage.isEmpty {
                    Text(fontValidationMessage)
                        .foregroundColor(isValidFont ? .green : .red)
                        .font(.caption)
                }
            }

            Section("Installation") {
                Button("Install Font") {
                    isShowingSafari = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.isShowingSafari = false
                        self.showingInstructions = true
                    }
                }
                .disabled(!isValidFont)

                Button("Show Installation Instructions") {
                    showingInstructions = true
                }
            }
        }
        .sheet(isPresented: $isShowingSafari) {
            if let url = serverURL {
                SafariView(url: url)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .sheet(isPresented: $showingInstructions) {
            NavigationView {
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

    func validateAndSetFont(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            fontValidationMessage = "Unable to access the selected file"
            isValidFont = false
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent

        // Check if it's a font collection first
        if fileExtension == "ttc" || fileExtension == "otc" {
            fontValidationMessage = "⚠️ Font collections (.ttc/.otc) are not supported by iOS"
            isValidFont = false
            fontName = nil
            showingCollectionWarning = true
            return
        }

        // Check file fileextension for supported single font formats
        let supportedExtensions = ["ttf", "otf"]
        guard supportedExtensions.contains(fileExtension) else {
            fontValidationMessage = "Unsupported file type. Please select a TrueType (.ttf) or OpenType (.otf) font file."
            isValidFont = false
            fontName = nil
            return
        }

        // Validate font data
        guard let fontData = try? Data(contentsOf: url), fontData.count > 0 else {
            fontValidationMessage = "Unable to read font file or file is empty"
            isValidFont = false
            fontName = nil
            return
        }

        // Basic font file signature validation
        let validationResult = validateFontSignature(data: fontData, fileextension: fileExtension)

        switch validationResult {
        case .valid:
            fontName = fileName
            fontValidationMessage = "✓ Valid \(fileExtension.uppercased()) font file detected"
            isValidFont = true
            startServerAndPrepareProfile(withFontURL: url)

        case .collection:
            fontValidationMessage = "⚠️ This file appears to be a font collection, which is not supported by iOS"
            isValidFont = false
            fontName = nil
            showingCollectionWarning = true

        case .invalid:
            fontValidationMessage = "Invalid font file format. The file doesn't appear to be a valid font."
            isValidFont = false
            fontName = nil
        }
    }

    enum FontValidationResult {
        case valid
        case collection
        case invalid
    }

    func validateFontSignature(data: Data, fileextension: String) -> FontValidationResult {
        guard data.count >= 4 else { return .invalid }

        let signature = data.prefix(4)

        // Check for font collection signatures first
        if signature.starts(with: "ttcf".data(using: .ascii) ?? Data()) {
            return .collection
        }

        // Check for valid single font signatures
        switch fileextension {
        case "ttf":
            // TrueType fonts start with 0x00010000 or "true"
            if signature.starts(with: [0x00, 0x01, 0x00, 0x00]) ||
               signature.starts(with: "true".data(using: .ascii) ?? Data()) {
                return .valid
            }

        case "otf":
            // OpenType fonts start with "OTTO"
            if signature.starts(with: "OTTO".data(using: .ascii) ?? Data()) {
                return .valid
            }

        default:
            break
        }

        return .invalid
    }

    func startServerAndPrepareProfile(withFontURL fontURL: URL) {
        // Stop server if already running
        server.stop()

        let fontProfilePath = "/font-profile.mobileconfig"

        server[fontProfilePath] = { request in
            HttpResponse.raw(200, "OK", ["Content-Type": "application/x-apple-aspen-config"]) { writer in
                do {
                    try writer.write(self.fontProfileData(from: fontURL))
                } catch {
                    print("Error writing profile data: \(error)")
                }
            }
        }

        do {
            try server.start(8080, forceIPv4: true)
            if let localURL = URL(string: "http://localhost:8080\(fontProfilePath)") {
                print(localURL)
                self.serverURL = localURL
            }
        } catch {
            print("Server could not start: \(error)")
        }
    }

    func fontProfileData(from fontURL: URL) -> Data {
        guard fontURL.startAccessingSecurityScopedResource() else {
            print("Unable to access the file")
            return Data()
        }

        defer {
            fontURL.stopAccessingSecurityScopedResource()
        }

        guard let fontData = try? Data(contentsOf: fontURL) else {
            print("Unable to read font data")
            return Data()
        }

        let base64Font = fontData.base64EncodedString()
        let fontFileName = fontURL.deletingPathExtension().lastPathComponent

        let profileString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>Name</key>
                    <string>\(fontFileName)</string>
                    <key>Font</key>
                    <data>
        \(base64Font)
                    </data>
                    <key>PayloadIdentifier</key>
                    <string>de.sivery.Toolbox.font.\(UUID().uuidString)</string>
                    <key>PayloadType</key>
                    <string>com.apple.font</string>
                    <key>PayloadUUID</key>
                    <string>\(UUID().uuidString)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                    <key>PayloadDisplayName</key>
                    <string>\(fontFileName) Font</string>
                </dict>
            </array>
            <key>PayloadDisplayName</key>
            <string>\(fontFileName) - Font Installation</string>
            <key>PayloadIdentifier</key>
            <string>de.sivery.Toolbox.fontinstallation.\(UUID().uuidString)</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(UUID().uuidString)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadDescription</key>
            <string>Installs the \(fontFileName) font</string>
        </dict>
        </plist>
        """
        return Data(profileString.utf8)
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

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.modalPresentationStyle = .fullScreen
        return safariViewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {}
}
