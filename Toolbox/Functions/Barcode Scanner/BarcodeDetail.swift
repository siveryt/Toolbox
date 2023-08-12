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

struct BarcodeDetail: View {
    @Environment(\.showingSheet) var showingSheet
    var barcode: ScannedBarcode?
    
    var body: some View {
        NavigationView {
            VStack {
//                Text(barcode?.content ?? "No content")
                List {
                    BarcodeTextProperty(content: barcode?.content, propertyName: "content")
                    BarcodeTextProperty(content: barcode?.type, propertyName: "type")
                    BarcodeTextProperty(content: formatDate(date: barcode?.date), propertyName: "date")
                    Image(uiImage: generateQRCode( barcode?.content ?? "error", type: barcode?.type))
                        .resizable()
                        .scaledToFit()
//                        .frame(width: 200, height: 300)
                }
                
                
            }
            .navigationBarTitle(barcode?.content ?? "No content")
            .navigationBarItems(trailing: backButton)
            .navigationBarTitleDisplayMode(.inline)
        }
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
    
//    func generateQRCode(_ string: String) -> UIImage {
//
//          if !string.isEmpty {
//
//              let data = string.data(using: String.Encoding.ascii)
//
//              let filter = CIFilter.qrCodeGenerator()
//              // Check the KVC for the selected code generator
//              filter.setValue(data, forKey: "inputMessage")
//
//              let transform = CGAffineTransform(scaleX: 15, y: 15)
//              let output = filter.outputImage?.transformed(by: transform)
//
//              return UIImage(ciImage: output!)
//          } else {
//              return UIImage()
//          }
//    }
    
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
            // Todo: handle back
            self.showingSheet?.wrappedValue = false
        }
    }
}


struct BarcodeTextProperty: View {
    
    var content: String?
    var propertyName: String
    
    var body: some View {
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
                Text(content ?? "No content")
                    
                Spacer()
            }
        }
    }
}

struct BarcodeDetail_Previews: PreviewProvider {
    static var previews: some View {
        return BarcodeDetail()
    }
}
