//
//  FontInstall.swift
//  Toolbox
//
//  Created by Christian Nagel on 01.05.24.
//

import SwiftUI
import UniformTypeIdentifiers
import Swifter
import CoreText

/// A single font face extracted from a font collection (.ttc/.otc), materialized
/// as a standalone sfnt so it can be installed individually (iOS can't install collections).
struct ExtractedFont: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
}

struct FontInstall: View {
    @State private var serverURL = URL(string: "about:blank")
    @State private var isFilePickerPresented = false
    @State private var fontName: String? = nil
    @State private var fontValidationMessage: String = ""
    @State private var isValidFont: Bool = false
    @State private var showingInstructions = false
    @State private var showingCollectionWarning = false
    @State private var collectionFonts: [ExtractedFont] = []
    @State private var showingCollectionPicker = false
    @State private var profileData: Data? = nil
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
                    installFont()
                }
                .disabled(!isValidFont)

                Button("Show Installation Instructions") {
                    showingInstructions = true
                }
            }
        }
        .sheet(isPresented: $showingInstructions) {
            NavigationView {
                InstallationInstructionsView()
                    .navigationTitle("Installation Guide")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingInstructions = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingCollectionPicker) {
            NavigationView {
                List {
                    Section {
                        ForEach(collectionFonts) { font in
                            Button {
                                selectExtractedFont(font)
                                showingCollectionPicker = false
                            } label: {
                                HStack {
                                    Text(font.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } footer: {
                        Text("iOS can only install one font at a time. This file is a collection — pick the font you want to install.")
                    }
                }
                .navigationTitle("Choose a Font")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showingCollectionPicker = false
                        }
                    }
                }
            }
        }
        .alert("Couldn't Read Collection", isPresented: $showingCollectionWarning) {
            Button("OK") { }
        } message: {
            Text("This file looks like a font collection, but its individual fonts couldn't be extracted. Please try a single font file (.ttf/.otf) instead.")
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

        // Read the file up front while we still hold access to the security-scoped
        // resource, so nothing needs to be read lazily after this call returns.
        guard let fontData = try? Data(contentsOf: url), fontData.count > 0 else {
            fontValidationMessage = "Unable to read font file or file is empty"
            isValidFont = false
            fontName = nil
            return
        }

        // Font collections (.ttc/.otc, or a "ttcf" signature) can't be installed
        // directly — split them into individual faces and let the user pick one.
        if fileExtension == "ttc" || fileExtension == "otc"
            || validateFontSignature(data: fontData, fileextension: fileExtension) == .collection {
            handleCollection(data: fontData)
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

        // Basic font file signature validation
        switch validateFontSignature(data: fontData, fileextension: fileExtension) {
        case .valid:
            // iOS profile installation rejects variable fonts (it reports them as an
            // unsupported "font collection"), so catch them here with a clear message.
            if isVariableFont(fontData) {
                fontValidationMessage = "⚠️ This is a variable font. iOS can't install variable fonts via profiles — use a static instance (e.g. a single weight) instead."
                isValidFont = false
                fontName = nil
                return
            }
            fontName = url.lastPathComponent
            fontValidationMessage = "✓ Valid \(fileExtension.uppercased()) font file detected"
            isValidFont = true
            prepareProfile(fontData: fontData, name: url.deletingPathExtension().lastPathComponent)

        case .collection:
            handleCollection(data: fontData)

        case .invalid:
            fontValidationMessage = "Invalid font file format. The file doesn't appear to be a valid font."
            isValidFont = false
            fontName = nil
        }
    }

    /// Split a font collection into individual faces. Presents a picker when there
    /// are multiple, auto-selects when there is only one, and warns if extraction fails.
    private func handleCollection(data: Data) {
        let fonts = FontCollectionSplitter.split(collectionData: data)

        switch fonts.count {
        case 0:
            fontValidationMessage = "⚠️ Couldn't extract fonts from this collection"
            isValidFont = false
            fontName = nil
            collectionFonts = []
            showingCollectionWarning = true
        case 1:
            selectExtractedFont(fonts[0])
        default:
            collectionFonts = fonts
            showingCollectionPicker = true
        }
    }

    /// Adopt a single face extracted from a collection as the font to install.
    private func selectExtractedFont(_ font: ExtractedFont) {
        if isVariableFont(font.data) {
            fontValidationMessage = "⚠️ “\(font.name)” is a variable font, which iOS can't install via profiles."
            isValidFont = false
            fontName = nil
            return
        }
        fontName = font.name
        fontValidationMessage = "✓ Extracted “\(font.name)” from collection"
        isValidFont = true
        prepareProfile(fontData: font.data, name: font.name)
    }

    /// True if the sfnt contains an `fvar` table, i.e. it's a variable font.
    /// iOS configuration-profile font payloads reject these outright.
    private func isVariableFont(_ data: Data) -> Bool {
        let base = data.startIndex
        guard data.count >= 12 else { return false }
        let numTables = (Int(data[base + 4]) << 8) | Int(data[base + 5])
        var offset = 12
        for _ in 0..<numTables {
            guard data.count >= offset + 16 else { break }
            // 'fvar' == 0x66 0x76 0x61 0x72
            if data[base + offset] == 0x66, data[base + offset + 1] == 0x76,
               data[base + offset + 2] == 0x61, data[base + offset + 3] == 0x72 {
                return true
            }
            offset += 16
        }
        return false
    }

    func installFont() {
        guard let url = serverURL else { return }

        // Configuration profiles can only be installed by the system Safari app,
        // not by an in-app SFSafariViewController. Opening the URL here backgrounds
        // us, so hold a background task to keep the local HTTP server responsive
        // while Safari fetches the profile from localhost.
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ServeFontProfile") {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }

        UIApplication.shared.open(url) { _ in
            showingInstructions = true
            // Give Safari time to download the profile before releasing the server.
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    backgroundTask = .invalid
                }
            }
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

    /// Build the configuration profile for the given font data and (re)start the
    /// local server that serves it. Works identically for a picked single font and
    /// for a face extracted from a collection.
    func prepareProfile(fontData: Data, name: String) {
        profileData = makeProfileData(fontData: fontData, name: name)
        startServer()
    }

    func startServer() {
        // Stop server if already running
        server.stop()

        let fontProfilePath = "/font-profile.mobileconfig"

        server[fontProfilePath] = { _ in
            HttpResponse.raw(200, "OK", ["Content-Type": "application/x-apple-aspen-config"]) { writer in
                do {
                    try writer.write(self.profileData ?? Data())
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

    func makeProfileData(fontData: Data, name: String) -> Data {
        let base64Font = fontData.base64EncodedString()
        let fontFileName = name

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
                    Text("✓ TrueType Collection (.ttc) - Split into single fonts")
                    Text("✓ OpenType Collection (.otc) - Split into single fonts")

                    Text("Note: Font collections contain several fonts in one file. iOS installs one font at a time, so a collection is split and you choose which font to install.")
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
                    Text("• Font collections (.ttc/.otc) are split so you can install one font at a time")
                }
            }
            .padding()
        }
    }
}

/// Splits a TrueType/OpenType font collection (.ttc/.otc) into standalone single-font
/// sfnt binaries. iOS configuration profiles install one font per payload, so each face
/// is reconstructed as its own font by enumerating the collection with CoreText and
/// copying that face's sfnt tables via CoreGraphics.
enum FontCollectionSplitter {
    static func split(collectionData: Data) -> [ExtractedFont] {
        // Write to a temp file so CoreText can read it; every table is materialized
        // below before the file is removed, so no lazy reads survive this call.
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("ttc")
        guard (try? collectionData.write(to: tmpURL)) != nil else { return [] }
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(tmpURL as CFURL) as? [CTFontDescriptor],
              !descriptors.isEmpty else {
            return []
        }

        var results: [ExtractedFont] = []
        var usedNames: Set<String> = []
        for (index, descriptor) in descriptors.enumerated() {
            let ctFont = CTFontCreateWithFontDescriptor(descriptor, 0, nil)
            let cgFont = CTFontCopyGraphicsFont(ctFont, nil)
            guard let sfnt = standaloneSFNT(from: cgFont) else { continue }

            var name = (CTFontCopyName(ctFont, kCTFontFullNameKey) as String?)
                ?? (CTFontCopyPostScriptName(ctFont) as String)
            if name.isEmpty { name = "Font \(index + 1)" }
            // A collection can technically repeat names; keep the picker unambiguous.
            if usedNames.contains(name) { name = "\(name) (\(index + 1))" }
            usedNames.insert(name)

            results.append(ExtractedFont(name: name, data: sfnt))
        }
        return results
    }

    /// Reassemble a standalone sfnt binary from a single CGFont's tables.
    private static func standaloneSFNT(from font: CGFont) -> Data? {
        guard let tagArray = font.tableTags else { return nil }
        let tagCount = CFArrayGetCount(tagArray)
        guard tagCount > 0 else { return nil }

        var tables: [(tag: UInt32, data: Data)] = []
        for i in 0..<tagCount {
            let raw = CFArrayGetValueAtIndex(tagArray, i)
            let tag = UInt32(truncatingIfNeeded: UInt(bitPattern: raw))
            guard let cfData = font.table(for: tag) else { continue }
            tables.append((tag, cfData as Data))
        }
        guard !tables.isEmpty else { return nil }
        return assembleSFNT(tables: tables)
    }

    private static let cffTag: UInt32 = 0x4346_4620  // 'CFF '
    private static let headTag: UInt32 = 0x6865_6164 // 'head'

    private static func assembleSFNT(tables rawTables: [(tag: UInt32, data: Data)]) -> Data {
        // The sfnt table directory must be sorted by tag.
        let tables = rawTables.sorted { $0.tag < $1.tag }
        let numTables = tables.count
        let hasCFF = tables.contains { $0.tag == cffTag }
        let sfntVersion: UInt32 = hasCFF ? 0x4F54_544F : 0x0001_0000 // 'OTTO' or 1.0

        // searchRange / entrySelector / rangeShift per the OpenType spec.
        var entrySelector: UInt16 = 0
        var pow2 = 1
        while pow2 * 2 <= numTables { pow2 *= 2; entrySelector += 1 }
        let searchRange = UInt16(pow2 * 16)
        let rangeShift = UInt16(numTables * 16) &- searchRange

        var header = Data()
        header.appendBE(sfntVersion)
        header.appendBE(UInt16(numTables))
        header.appendBE(searchRange)
        header.appendBE(entrySelector)
        header.appendBE(rangeShift)

        let directorySize = 16 * numTables
        var runningOffset = 12 + directorySize
        var directory = Data()
        var body = Data()
        var headBodyOffset: Int? = nil // absolute offset of the head table in the file

        for table in tables {
            // Pad each table to a 4-byte boundary.
            var padded = table.data
            let remainder = padded.count % 4
            if remainder != 0 { padded.append(contentsOf: repeatElement(UInt8(0), count: 4 - remainder)) }

            if table.tag == headTag && padded.count >= 12 {
                // head's own checksum and the whole-font checksum are both computed
                // with checksumAdjustment (bytes 8..<12) treated as zero.
                padded.replaceSubrange(8..<12, with: [0, 0, 0, 0])
                headBodyOffset = 12 + directorySize + body.count
            }

            directory.appendBE(table.tag)
            directory.appendBE(checksum(of: padded))
            directory.appendBE(UInt32(runningOffset))
            directory.appendBE(UInt32(table.data.count)) // length is unpadded
            body.append(padded)
            runningOffset += padded.count
        }

        var font = header
        font.append(directory)
        font.append(body)

        // Patch head.checksumAdjustment = 0xB1B0AFBA - checksum(entire font).
        if let headOffset = headBodyOffset, font.count >= headOffset + 12 {
            let adjustment = 0xB1B0_AFBA &- checksum(of: font)
            var be = adjustment.bigEndian
            withUnsafeBytes(of: &be) { bytes in
                font.replaceSubrange(headOffset + 8 ..< headOffset + 12, with: bytes)
            }
        }
        return font
    }

    /// sfnt checksum: the data (always 4-byte aligned here) summed as big-endian UInt32 words.
    private static func checksum(of data: Data) -> UInt32 {
        var sum: UInt32 = 0
        var word: UInt32 = 0
        var count = 0
        for byte in data {
            word = (word << 8) | UInt32(byte)
            count += 1
            if count % 4 == 0 {
                sum = sum &+ word
                word = 0
            }
        }
        return sum
    }
}

private extension Data {
    mutating func appendBE(_ value: UInt32) {
        var be = value.bigEndian
        Swift.withUnsafeBytes(of: &be) { append(contentsOf: $0) }
    }
    mutating func appendBE(_ value: UInt16) {
        var be = value.bigEndian
        Swift.withUnsafeBytes(of: &be) { append(contentsOf: $0) }
    }
}

