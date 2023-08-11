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
    @State var detailSheet = false
    @State private var itemIndex: Int? = nil
    @Environment(\.managedObjectContext) var managedContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\.date, order: .reverse)]) var codes: FetchedResults<ScannedBarcode>
    
    
    var body: some View {
        VStack{
            if(codes.count > 0){
                List(){
                    ForEach(Array(codes.enumerated()), id: \.offset) { index, code in
                        Button(code.content!){
                            itemIndex = index
                            detailSheet = true
                        }
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
            BarcodeScanner()
            .presentationDetents([.medium, .large])
            
        }
        .sheet(item: Binding(
            get: { detailSheet && itemIndex ? true : nil },
            set: { _ in })) { _ in
            BarcodeDetail(barcode: codes[itemIndex])
                .environment(\.showingSheet, self.detailSheet)
        }
        
    }
    private func deleteCode(offsets: IndexSet) {
            withAnimation {
                offsets.map { codes[$0] }
                .forEach(managedContext.delete)
                
                SBDataController().save(context: managedContext)
            }
        }
}



struct BarcodeScanner: View {
    
    @State private var scanError = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) var managedContext
    
    var body: some View {
        
        ZStack {
            if(scanError) {
                VStack{
                    Text("Enable camera access in settings to use the Barcode Scanner.")
                    Button("Settings") {
                        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                        }
                    }
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
                            dismiss()
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
                        dismiss()
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
        
    }
    
}

struct Barcode_Previews: PreviewProvider {
    static var previews: some View {
        Barcode()
    }
}
