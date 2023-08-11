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
                Text(barcode?.content ?? "No content")
            }
            .navigationBarTitle(barcode?.content ?? "No content")
            .navigationBarItems(trailing: backButton)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var backButton: some View {
        Button("Done") {
            // Todo: handle back
            self.showingSheet?.wrappedValue = false
        }
    }
}


struct BarcodeDetail_Previews: PreviewProvider {
    static var previews: some View {
        return BarcodeDetail()
    }
}
