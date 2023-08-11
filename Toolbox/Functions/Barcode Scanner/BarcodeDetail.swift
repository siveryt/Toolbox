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
                }
                // Todo generate image of code
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
