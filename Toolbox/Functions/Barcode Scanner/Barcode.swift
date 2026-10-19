//
//  Barcode.swift
//  Toolbox
//
//  Created by Christian Nagel on 02.03.23.
//

import SwiftUI
import CoreData
import AVFoundation //import to access barcode types you want to scan
import Haptica
import CodeScanner

struct Barcode: View {
    @State var scanSheet = false
    @StateObject private var selectedItemIndex = SelectedItemIndex()
    @Environment(\.managedObjectContext) var managedContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\.date, order: .reverse)]) var codes: FetchedResults<ScannedBarcode>
    
    var body: some View {
        VStack {
            if codes.count > 0 {
                List {
                    ForEach(Array(codes.enumerated()), id: \.offset) { index, code in
                        Button(code.content ?? "") {
                            selectedItemIndex.index = index
                        }
                    }
                    .onDelete(perform: deleteCode)
                }
                    
            } else {
                ContentUnavailableView {
                    Label("No Barcodes", systemImage: "barcode")
                } description: {
                    Text("Tap \(Image(systemName: "viewfinder")) to scan your first barcode.")
                }
            }
        }
        
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Barcode")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    scanSheet = true
                }) {
                    Image(systemName: "viewfinder")
                }
                .accessibilityLabel(NSLocalizedString("Scan Barcode", comment: "Barcode Scanner: accessibility label of the toolbar button that opens the camera to scan a code"))
            }
        }
        .sheet(isPresented: $scanSheet) {
            BarcodeScanner()
            .presentationDetents([.medium, .large])
        }
        
        .sheet(item: $selectedItemIndex.index) { index in
                BarcodeDetail(barcode: codes[index])
        }
        
    }
    func deleteCode(offsets: IndexSet) {
        withAnimation {
            offsets.map { codes[$0] }
                .forEach(managedContext.delete)
            
            SBDataController.shared.save(context: managedContext)
        }
    }
    
}

struct BarcodeScanner: View {

    private enum ScanFailure {
        case permissionDenied
        case cameraUnavailable
    }

    /// CodeScanner reports a denied permission, but stays black when access is restricted (Screen Time, MDM) or there's no camera.
    @State private var scanFailure: ScanFailure? = {
        if AVCaptureDevice.authorizationStatus(for: .video) == .restricted { return .permissionDenied }
        if AVCaptureDevice.default(for: .video) == nil { return .cameraUnavailable }
        return nil
    }()
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) var managedContext

    var body: some View {

        ZStack {
            switch scanFailure {
            case .permissionDenied:
                PermissionDeniedView(
                    title: NSLocalizedString("Camera Access Required", comment: "Missing permission view: title when camera access was denied"),
                    systemImage: "camera",
                    description: NSLocalizedString("Enable camera access in settings to use the Barcode Scanner.", comment: "Barcode Scanner: shown when camera access was denied")
                )
            case .cameraUnavailable:
                ContentUnavailableView(
                    NSLocalizedString("Camera Unavailable", comment: "Barcode Scanner: title when the camera can't be used, e.g. on a device without a camera"),
                    systemImage: "camera",
                    description: Text(NSLocalizedString("The camera can't be used to scan barcodes on this device right now.", comment: "Barcode Scanner: shown when the camera could not be started for a reason other than a denied permission"))
                )
            case nil:
                CodeScannerView(codeTypes: [.aztec, .code39, .code93, .code128, .dataMatrix, .ean8, .ean13, .interleaved2of5, .itf14, .pdf417, .qr, .upce], shouldVibrateOnSuccess: false) { response in

                    switch response {
                        case .success(let result):
                            withAnimation {
                                SBDataController.shared.addBarcode(content: result.string, type: result.type.friendlyName, context: managedContext)
                            }
                            Haptic.impact(.medium).generate()
                            dismiss()
                        case .failure(let error):
                            switch error {
                            case .permissionDenied:
                                scanFailure = .permissionDenied
                            case .badInput, .badOutput, .initError:
                                scanFailure = .cameraUnavailable
                            }
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

}

struct Barcode_Previews: PreviewProvider {
    static var previews: some View {
        Barcode()
    }
}
