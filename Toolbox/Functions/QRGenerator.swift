//
//  QRGenerator.swift
//  Toolbox
//
//  Created by Christian Nagel on 03.04.22.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

enum qrTypes {
    case text, url, wifi, mail
}

enum wifiEnc: String {
    case wep = "WEP"
    case wpa = "WPA"
    case nopassword = "nopass"
}



struct QRGenerator: View {
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    
    /// Returns nil when the content doesn't fit into a QR code.
    func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10.0, y: 10.0)) {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return nil
    }
    
    /// Escapes the characters that have a meaning in the WIFI: and MATMSG: formats.
    static func escape(_ string: String) -> String {
        var escaped = ""
        for character in string {
            if "\\;,:\"".contains(character) {
                escaped.append("\\")
            }
            escaped.append(character)
        }
        return escaped
    }
    
    /// Adds https:// to addresses typed without a scheme, so scanners open them as a link.
    static func normalizedURL(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        // "mailto:…" or "https://…" have a scheme, "localhost:8080" is a host with a port
        if let scheme = trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*:", options: .regularExpression),
           !(trimmed[scheme.upperBound...].first?.isNumber ?? false) {
            return trimmed
        }
        return "https://" + trimmed
    }
    
    /// The text encoded in the QR code, or nil while the required fields are empty.
    var payload: String? {
        switch qrType {
        case .text:
            return text.isEmpty ? nil : text
        case .url:
            let link = QRGenerator.normalizedURL(self.url)
            return link.isEmpty ? nil : link
        case .wifi:
            guard !wifiSSID.isEmpty else { return nil }
            var payload = "WIFI:T:\(wifiTYPE.rawValue);S:\(QRGenerator.escape(wifiSSID));"
            if wifiTYPE != .nopassword {
                payload += "P:\(QRGenerator.escape(wifiPASSWORD));"
            }
            if wifiHIDDEN {
                payload += "H:true;"
            }
            return payload + ";"
        case .mail:
            guard !mailReceiver.isEmpty else { return nil }
            return "MATMSG:TO:\(QRGenerator.escape(mailReceiver));SUB:\(QRGenerator.escape(mailSubject));BODY:;;"
        }
    }
    
    @State private var qrType: qrTypes = .url
    @State var text = ""
    @State var url = ""
    @State var wifiSSID = ""
    @State var wifiPASSWORD = ""
    @State var wifiTYPE:wifiEnc = .wpa
    @State var wifiHIDDEN = false
    @State var mailReceiver = ""
    @State var mailSubject = ""
    @State var isShareSheet = false
    
    var body: some View {
        Form {
            Section("QR-Code Content") {
                Picker("Type", selection: $qrType){
                    Text("URL").tag(qrTypes.url)
                    Text("Text").tag(qrTypes.text)
                    Text("Wi-Fi").tag(qrTypes.wifi)
                    Text("Mail").tag(qrTypes.mail)
                }
                switch qrType {
                case .text:
                    TextEditor(text: $text)
                        .submitLabel(.done)
                case .url:
                    HStack {
                        Text("URL")
                        TextField("toolbox.sivery.de", text: $url)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
                            .textCase(/*@START_MENU_TOKEN@*/.lowercase/*@END_MENU_TOKEN@*/)
                            .keyboardType(.URL)
                            .submitLabel(.done)
                            .disableAutocorrection(true)
                    }
                case .wifi:
                    HStack {
                        Text(NSLocalizedString("SSID", comment: "QR-Code Generator: label of the Wi-Fi network name field (SSID)"))
                        TextField("Network Name", text: $wifiSSID)
                            .multilineTextAlignment(.trailing)
                            .disableAutocorrection(true)
                    }
                    HStack {
                        Text("Password")
                        SecureField("12345678", text: $wifiPASSWORD)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .disableAutocorrection(true)
                    }
                    Picker("Encryption", selection: $wifiTYPE){
                        Text("WEP").tag(wifiEnc.wep)
                        Text("WPA (most common)").tag(wifiEnc.wpa)
                        Text("No Encryption").tag(wifiEnc.nopassword)
                    }
                    Toggle(isOn: $wifiHIDDEN) {
                        Text("Hidden")
                    }
                case .mail:
                    HStack {
                        Text("Receiver")
                        TextField("toolbox@sivery.de", text: $mailReceiver)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .multilineTextAlignment(.trailing)
                        .disableAutocorrection(true)
                    }
                    HStack {
                        Text("Subject")
                        TextField("Great Feature Idea!", text: $mailSubject)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            if let payload, let image = generateQRCode(from: payload) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .onTapGesture {
                        shareFromView(shareItem: [image])
                    }
            } else if payload == nil {
                ContentUnavailableView {
                    Label(NSLocalizedString("No QR Code Yet", comment: "QR-Code Generator: title shown instead of the QR code while the required fields are empty"), systemImage: "qrcode")
                } description: {
                    Text(NSLocalizedString("Fill in the fields above to create a QR code.", comment: "QR-Code Generator: explanation shown instead of the QR code while the required fields are empty"))
                }
            } else {
                ContentUnavailableView {
                    Label(NSLocalizedString("Too Much Content", comment: "QR-Code Generator: title shown instead of the QR code when the content doesn't fit into one"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(NSLocalizedString("A QR code can't hold this much. Shorten the content to create one.", comment: "QR-Code Generator: explanation shown instead of the QR code when the content doesn't fit into one"))
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if let payload, let image = generateQRCode(from: payload) {
                        shareFromView(shareItem: [image])
                    }
                }, label: {Image(systemName: "square.and.arrow.up")})
                .disabled(payload == nil)
            }
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("QR-Generator")
        
    }
}

                      
struct QRGenerator_Previews: PreviewProvider {
    static var previews: some View {
        QRGenerator()
    }
}
