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
    private let server = HttpServer()

    var body: some View {
        VStack {
            Button("Select Font File") {
                isFilePickerPresented = true
            }
            .fileImporter(
                isPresented: $isFilePickerPresented,
                allowedContentTypes: [.font],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    startServerAndPrepareProfile(withFontURL: url)
                    isShowingSafari = true
                case .failure(let error):
                    print("Error selecting the file: \(error.localizedDescription)")
                }
            }

            Button("Install Font") {
                isShowingSafari = true
            }
            .sheet(isPresented: $isShowingSafari) {
                if let url = serverURL {
                    SafariView(url: url)
                }
            }
        }
    }

    func startServerAndPrepareProfile(withFontURL fontURL: URL) {
        
        let fontProfilePath = "/font-profile.mobileconfig"

        server["\(fontProfilePath)"] = { request in
            HttpResponse.raw(200, "OK", ["Content-Type": "application/x-apple-aspen-config"]) { writer in
                try? writer.write(self.fontProfileData(from: fontURL))
            }
        }

        do {
            try server.start(8080, forceIPv4: true)
            if let localURL = URL(string: "http://localhost:8080\(fontProfilePath)") {
                print(localURL)
                self.serverURL = localURL
            }
        } catch {
            print("Server could not start")
        }
    }

    func fontProfileData(from fontURL: URL) -> Data {
        guard fontURL.startAccessingSecurityScopedResource() else {
            print("Unable to access the file")
            return Data()
        }
                
        guard let fontData = try? Data(contentsOf: fontURL) else { return Data() }
        defer {
            fontURL.stopAccessingSecurityScopedResource()
        }
        let base64Font = fontData.base64EncodedString()
        let profileString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>\(fontURL.lastPathComponent)</key>
                    <data>
                        \(base64Font)
                    </data>
                    <key>PayloadIdentifier</key>
                    <string>de.sivery.Toolbox.font</string>
                    <key>PayloadType</key>
                    <string>com.apple.font</string>
                    <key>PayloadUUID</key>
                    <string>\(UUID().uuidString)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                </dict>
            </array>
            <key>PayloadDisplayName</key>
            <string>\(fontURL.lastPathComponent) - Toolbox Font Installation</string>
            <key>PayloadIdentifier</key>
            <string>de.sivery.Toolbox.fontinstallation</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(UUID().uuidString)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """
        return Data(profileString.utf8)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // No update action needed
    }
}
