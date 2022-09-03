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
    
    
    func generateQRCode(from string: String) -> UIImage {
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10.0, y: 10.0)) {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
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
            Section("QR-Code content") {
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
                        Text("SSID")
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

            switch qrType {
            case .text:
                Image(uiImage: generateQRCode(from: text))
                .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .onTapGesture {
                        shareFromView(shareItem: [generateQRCode(from: text)])

                    }
                    
            case .wifi:
                Image(uiImage: generateQRCode(from: "WIFI:T:\(wifiTYPE);S:\(wifiSSID);P:\(wifiPASSWORD);H:\(String(wifiHIDDEN));"))
                .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .onTapGesture {

                        shareFromView(shareItem: [generateQRCode(from: "WIFI:T:\(wifiTYPE);S:\(wifiSSID);P:\(wifiPASSWORD);H:\(String(wifiHIDDEN));")])

                    }
            case .url:
                Image(uiImage: generateQRCode(from: url))
                .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .onTapGesture {
                        
                        shareFromView(shareItem: [generateQRCode(from: url)])

                    }
            case .mail:
                Image(uiImage: generateQRCode(from: "MATMSG:TO:\(mailReceiver);SUB:\(mailSubject);BODY:;;"))
                .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .onTapGesture {
                        shareFromView(shareItem: [generateQRCode(from: "MATMSG:TO:\(mailReceiver);SUB:\(mailSubject);BODY:;;")])

                    }
            }
            


        }
        .navigationBarItems(trailing:
                                Button(action: {
            switch qrType {
            case .text:
                shareFromView(shareItem: [generateQRCode(from: text)])
            case .wifi:
                shareFromView(shareItem: [generateQRCode(from: "WIFI:T:\(wifiTYPE);S:\(wifiSSID);P:\(wifiPASSWORD);H:\(String(wifiHIDDEN));")])
            case .url:
                shareFromView(shareItem: [generateQRCode(from: url)])
            case .mail:
                shareFromView(shareItem: [generateQRCode(from: "MATMSG:TO:\(mailReceiver);SUB:\(mailSubject);BODY:;;")])
            }
        }, label: {Image(systemName: "square.and.arrow.up")})
        )
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("QR-Generator")
        
    }
}

                      
struct QRGenerator_Previews: PreviewProvider {
    static var previews: some View {
        QRGenerator()
    }
}
