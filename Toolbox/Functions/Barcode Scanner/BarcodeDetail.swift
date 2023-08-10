//
//  BarcodeDetail.swift
//  Toolbox
//
//  Created by Christian Nagel on 10.08.23.
//

import Foundation
import SwiftUI

struct BarcodeDetail: View {
    
    @Environment(\.managedObjectContext) var managedObjContext
    @Environment(\.dismiss) var dismiss
    
    var barcode: FetchedResults<ScannedBarcode>.Element
    
    var body: some View {
        Text(barcode.content!)
    }
    
}
