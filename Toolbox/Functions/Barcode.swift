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
    
    @State private var scanError = false
    
    
    
    var body: some View {
        VStack{
            if(codes.count > 0){
                List(){
                    ForEach(codes) { code in
                        Text(code.content!)
                    }
                    .onDelete(perform: deleteCode)
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
                if(scanError) {
                    VStack{
                        Text("Enable camera access in settings to use the Barcode Scanner.")
                        Button("Settings") {
                            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                            }
                        }
//                        .tint(.primary)
                            
                    }
                } else{
                    CodeScannerView(codeTypes: [.aztec, .code39, .code93, .code128, .dataMatrix, .ean8, .ean13, .interleaved2of5, .itf14, .pdf417, .qr, .upce], shouldVibrateOnSuccess: false) { response in
                        
                        switch response {
                            case .success(let result):
                                print("Found code: \(result.string)")
                                withAnimation {
                                    SBDataController().addBarcode(content: result.string, type: result.type.friendlyName, context: managedContext)
                                }
                                Haptic.impact(.medium).generate()
                                scanSheet = false
                            case .failure(let error):
                                scanError = true
                                print(error.localizedDescription)
                            }
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
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.secondary, .tertiary)
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
    private func deleteCode(offsets: IndexSet) {
            withAnimation {
                offsets.map { codes[$0] }
                .forEach(managedContext.delete)
                
                // Saves to our database
                SBDataController().save(context: managedContext)
            }
        }
}

struct Barcode_Previews: PreviewProvider {
    static var previews: some View {
        Barcode()
    }
}
