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
        NavigationView {
            VStack {
                List {
                    KeyValueProperty(content: barcode?.content, propertyName: NSLocalizedString("content", comment: "Barcode"))
                        .environment(\.copyToast, $isPresentingToast)
                    KeyValueProperty(content: barcode?.type, propertyName: NSLocalizedString("type", comment: "Barcode"))
                        .environment(\.copyToast, $isPresentingToast)
                    KeyValueProperty(content: formatDate(date: barcode?.date), propertyName: NSLocalizedString("date", comment: "Barcode"))
                        .environment(\.copyToast, $isPresentingToast)
                    Image(uiImage: generateQRCode( barcode?.content ?? "error", type: barcode?.type))
                        .resizable()
                        .scaledToFit()
                }
                
                
            }
            .navigationBarTitle(barcode?.content ?? "No Content")
            .navigationBarItems(trailing: backButton)
            .navigationBarTitleDisplayMode(.inline)
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
    }
        
    
    func formatDate(date: Date?) -> String {
        
        if date == nil {
            return "nil"
        }
        
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .medium
            return formatter.string(from: date!)
    }
    
    func generateQRCode(_ string: String, type: String?) -> UIImage {
        let context = CIContext()
        
        if(type == "Aztec"){
        
            let filter = CIFilter.aztecCodeGenerator()
            filter.message = Data(string.utf8)

            if let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 15, y: 15)) {
                if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                    return UIImage(cgImage: cgimg)
                }
            }
        }else if(type == "QR Code"){
            
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(string.utf8)

            if let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 15, y: 15)) {
                if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                    return UIImage(cgImage: cgimg)
                }
            }
        }else if(type == "PDF417"){
            
            let filter = CIFilter.pdf417BarcodeGenerator()
            filter.message = Data(string.utf8)

            if let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 15, y: 15)) {
                if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                    return UIImage(cgImage: cgimg)
                }
            }
        }else{
            
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = Data(string.utf8)

            if let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 15, y: 15)) {
                if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                    return UIImage(cgImage: cgimg)
                }
            }
        }

        

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
      
    
    private var backButton: some View {
        Button("Done") {
            dismiss()
        }
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
                        Text(content ?? "No Content")
                        Spacer()
                    }
                }
        }).tint(.primary)
        
        
    }
}
