//
//  Barcode.swift
//  Toolbox
//
//  Created by Christian Nagel on 02.03.23.
//

import SwiftUI
import CarBode
import AVFoundation //import to access barcode types you want to scan

struct Barcode: View {
    
    @State private var scanSheet = false
    
    var body: some View {
        VStack{
            
            Text("Click on the \(Image(systemName: "viewfinder")) to scan your first barcode")
            
//            CBScanner(
//                supportBarcode: .constant([.qr, .code128]), //Set type of barcode you want to scan
//                scanInterval: .constant(0.5) //Event will trigger every 5 seconds
//            ){
//                //When the scanner found a barcode
//                print("BarCodeType =",$0.type.rawValue, "Value =",$0.value)
//            }
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Barcode")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    scanSheet = true
                }, label: {
                    Image(systemName: "viewfinder")
                })
            }
        }
        .sheet(isPresented: $scanSheet) {
                            Text("Sheet happens")
                                .presentationDetents([.medium, .large])
//                                .presentationBackgroundInteraction(.enabled)
                        }
    }
}

struct Barcode_Previews: PreviewProvider {
    static var previews: some View {
        Barcode()
    }
}
