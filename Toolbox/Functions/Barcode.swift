//
//  Barcode.swift
//  Toolbox
//
//  Created by Christian Nagel on 02.03.23.
//

import SwiftUI
import AVFoundation //import to access barcode types you want to scan
import Haptica
import CodeScanner

struct Barcode: View {
    
    @State private var scanSheet = false
    @Environment(\.managedObjectContext) var managedContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\.date, order: .reverse)]) var codes: FetchedResults<ScannedBarcode>
    
    
    
    var body: some View {
        VStack{
            if(codes.count > 0){
                List(){
                    ForEach(codes) { code in
                        Text(code.content!)
                    }
                }
                
            } else{
                Text("Click on the \(Image(systemName: "viewfinder")) to scan your first barcode")
            }
            
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
            ZStack {
                CodeScannerView(codeTypes: [.aztec, .code39, .code93, .code128, .dataMatrix, .ean8, .ean13, .interleaved2of5, .itf14, .pdf417, .qr, .upce], shouldVibrateOnSuccess: false) { response in
                    if case let .success(result) = response {
                        SBDataController().addBarcode(content: result.string, type: result.type.friendlyName, context: managedContext)
                        Haptic.impact(.medium).generate()
                        scanSheet = false
                    }
                }
                VStack {
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            scanSheet = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.secondary)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                    }
                    Spacer()
                }
            }
            .presentationDetents([.medium, .large])
            
        }
        
        
    }
}

struct Barcode_Previews: PreviewProvider {
    static var previews: some View {
        Barcode()
    }
}
