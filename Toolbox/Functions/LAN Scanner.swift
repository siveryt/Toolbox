//
//  LAN Scanner.swift
//  Toolbox
//
//  Created by Christian Nagel on 13.08.23.
//

import SwiftUI
import LanScanner
import ToastSwiftUI

struct LAN_Scanner: View {
    
    @ObservedObject var viewModel = CountViewModel()
    @State var showAlert: Bool = false
    @State var detailSheet = false
    @State private var itemIndex: Int? = nil
    @State var scanning = false

    var body: some View {
        
        Form{
            if(!scanning){
            Button("Start scanner"){
                viewModel.reload()
                withAnimation(.linear(duration: 0.1)){
                    scanning = true
                    }
            }} else {
                Button("Stop scanner"){
                    viewModel.stop()
                    scanning = false
                }
            }
            
            HStack {
                Spacer()
                ProgressView(value: viewModel.progress)
                    .frame(height: 20)
            }
            Section{
                ForEach(Array(viewModel.connectedDevices.enumerated()), id: \.offset) { index, device in
            Button(action: {itemIndex = index
                detailSheet = true}, label: {VStack(alignment: .leading) {
                Text(device.ipAddress)
                    .font(.body)
                Text(device.mac)
                    .font(.caption)
            }})
            .tint(.primary)

            }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("LAN Scanner")
        .sheet(isPresented: Binding<Bool>(
            get: { ($itemIndex.wrappedValue != nil) && detailSheet },
            set: { _ in self.detailSheet = false }
        )) {
            if let index = itemIndex, index < viewModel.connectedDevices.count {
                LANDetail(device: viewModel.connectedDevices[index])
                    .environment(\.showingSheet, self.$detailSheet)
            }
                
        }
        
        
        
    }
}

struct LANDetail: View {
    
    var device: LanDevice
    
    @Environment(\.showingSheet) var showingSheet
    @State var isPresentingToast = false
    
    var body: some View {
        NavigationView {
            VStack {
//                Text(barcode?.content ?? "No content")
                List {
                    KeyValueProperty(content: device.name, propertyName: NSLocalizedString("ip", comment: "LAN Scanner"))
                        .environment(\.copyToast, $isPresentingToast)
                    if(device.name != device.ipAddress){
                        KeyValueProperty(content: device.ipAddress, propertyName: NSLocalizedString("hostname", comment: "LAN Scanner"))
                            .environment(\.copyToast, $isPresentingToast)
                    }
                    KeyValueProperty(content: device.mac, propertyName: NSLocalizedString("mac", comment: "LAN Scanner"))
                        .environment(\.copyToast, $isPresentingToast)
                    if(device.brand != ""){
                        KeyValueProperty(content: device.brand, propertyName: NSLocalizedString("brand", comment: "LAN Scanner"))
                            .environment(\.copyToast, $isPresentingToast)
                    }
                    
//                        .frame(width: 200, height: 300)
                }
                
                
            }
            .navigationBarTitle(device.ipAddress)
            .navigationBarItems(trailing: Button("Done") {
                // Todo: handle back
//                self.showingSheet?.wrappedValue = false
            })
            .navigationBarTitleDisplayMode(.inline)
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
    }
}


struct LAN_Scanner_Previews: PreviewProvider {
    static var previews: some View {
        LAN_Scanner()
    }
}



class CountViewModel: ObservableObject {

    @Published var connectedDevices = [LanDevice]()
    @Published var progress: CGFloat = .zero
    @Published var title: String = .init()
    @Published var showAlert = false

    private lazy var scanner = LanScanner(delegate: self)

    func start() {
        scanner.start()
    }
    
    func stop() {
        scanner.stop()
    }

    func reload() {
        connectedDevices.removeAll()
        scanner.start()
    }
}

extension CountViewModel: LanScannerDelegate {
    func lanScanHasUpdatedProgress(_ progress: CGFloat, address: String) {
        self.progress = progress
        self.title = address
    }

    func lanScanDidFindNewDevice(_ device: LanDevice) {
        connectedDevices.append(device)
    }

    func lanScanDidFinishScanning() {
        showAlert = true
    }
}

extension LanDevice: Identifiable {
    public var id: UUID { .init() }
}
