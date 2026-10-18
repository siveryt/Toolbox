//
//  BarcodeDetail.swift
//  Toolbox
//
//  Created by Christian Nagel on 10.08.23.
//

import SwiftUI
import CoreData
import AVFoundation
import Foundation
import UIKit
import CoreImage.CIFilterBuiltins
import Haptica
import ToastSwiftUI

struct BarcodeDetail: View {
    var barcode: ScannedBarcode?
    @State var isPresentingToast = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    KeyValueProperty(content: barcode?.content, propertyName: NSLocalizedString("content", comment: "Barcode Scanner details: label of the scanned code's content"))
                        .environment(\.copyToast, $isPresentingToast)
                    KeyValueProperty(content: barcode?.type, propertyName: NSLocalizedString("type", comment: "Barcode Scanner details: label of the scanned code's type, e.g. QR Code"))
                        .environment(\.copyToast, $isPresentingToast)
                    KeyValueProperty(content: formatDate(date: barcode?.date), propertyName: NSLocalizedString("date", comment: "Barcode Scanner details: label of the date the code was scanned"))
                        .environment(\.copyToast, $isPresentingToast)
                    // Only types that can be redrawn exactly as scanned get an image; others show their content only.
                    if let content = barcode?.content, let image = generateBarcode(content, type: barcode?.type) {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    }
                }
                
                
            }
            .navigationTitle("Details")
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
    }
        
    
    func formatDate(date: Date?) -> String {
        
        guard let date else {
            return NSLocalizedString("Unknown date", comment: "Barcode Scanner details: shown instead of the scan date when it is missing")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Redraws the code for the types Core Image can generate faithfully (QR Code, Aztec, PDF417, Code 128).
    /// Returns nil for every other type (EAN, UPC, Code 39, ITF, Data Matrix, ...), so no misleading image is shown.
    func generateBarcode(_ string: String, type: String?) -> UIImage? {
        let outputImage: CIImage?

        switch type {
        case "QR Code":
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(string.utf8)
            outputImage = filter.outputImage
        case "Aztec":
            let filter = CIFilter.aztecCodeGenerator()
            filter.message = Data(string.utf8)
            outputImage = filter.outputImage
        case "PDF417":
            let filter = CIFilter.pdf417BarcodeGenerator()
            filter.message = Data(string.utf8)
            outputImage = filter.outputImage
        case "Code 128":
            // Code 128 only encodes ASCII
            guard let data = string.data(using: .ascii) else { return nil }
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = data
            outputImage = filter.outputImage
        default:
            return nil
        }

        guard let image = outputImage?.transformed(by: CGAffineTransform(scaleX: 15, y: 15)),
              let cgimg = CIContext().createCGImage(image, from: image.extent) else {
            return nil
        }
        return UIImage(cgImage: cgimg)
    }
}


struct KeyValueProperty: View {
    
    var content: String?
    var propertyName: String
    @Environment(\.copyToast) var copyToast
    
    var body: some View {
        
            
        Button(action: {
            withAnimation {
                copyToast?.wrappedValue = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    copyToast?.wrappedValue = false
                }
            }
            UIPasteboard.general.string = content
        }, label:
        {
                VStack{
                    HStack {
                        Text(propertyName)
                            .font(.callout)
                            .dynamicTypeSize(.small)

                            .textCase(/*@START_MENU_TOKEN@*/.uppercase/*@END_MENU_TOKEN@*/)
                        .foregroundColor(.secondary)
                        Spacer()
                    }
                    HStack {
                        Text(content ?? NSLocalizedString("No Content", comment: "Barcode Scanner details: shown when a scanned code has no content"))
                        Spacer()
                    }
                }
        }).tint(.primary)
        
        
    }
}
