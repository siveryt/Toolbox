//
//  LAN Scanner.swift
//  Toolbox
//
//  Created by Christian Nagel on 13.08.23.
//

import SwiftUI
import LanScanner
import ToastSwiftUI
import Network
import Foundation

struct LAN_Scanner: View {
    
    @ObservedObject var viewModel = CountViewModel()
    @State var showAlert: Bool = false
    @State var detailSheet = false
    @State private var itemIndex: Int? = nil
    @State var scanning = false
    @State private var showNoNetworkPermissionText = false
    @State var isPresentingToast = false

    var body: some View {
        

        
        VStack {
                    if showNoNetworkPermissionText {
                        Text("Toolbox does not have network permissions. Please allow local network access in the settings.")
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Open Settings") {
                            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                            }
                        }
                    } else {
                        Form{
                            if(!viewModel.scanning){
                            Button("Start Scanner"){
                                viewModel.reload()
                                withAnimation(.linear(duration: 0.1)){
                                    viewModel.scanning = true
                                    }
                            }} else {
                                Button("Stop Scanner"){
                                    viewModel.stop()
                                    viewModel.scanning = false
                                }
                            }
                            
                            HStack {
                                Spacer()
                                ProgressView(value: viewModel.progress)
                                    .frame(height: 20)
                            }
                            Section{
                                ForEach(Array(viewModel.connectedDevices.enumerated()), id: \.offset) { index, device in
                                    Button(action: {
                                        if(device.ipAddress == device.name){
                                            withAnimation {
                                                isPresentingToast = true
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                withAnimation {
                                                    isPresentingToast = false
                                                }
                                            }
                                            UIPasteboard.general.string = device.ipAddress
                                        } else {
                                            itemIndex = index
                                            detailSheet = true
                                        }
                                    }, label: {VStack(alignment: .leading) {
                                Text(device.ipAddress)
                                    .font(.body)
                                    if(device.ipAddress != device.name){
                                        Text(device.name)
                                            .font(.caption)
                                    }
                            }})
                            .tint(.primary)

                            }
                            }
                        }
                        
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
                .onAppear {
                    checkNetworkPermission()
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("LAN Scanner")
                .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)

        
        
    }
    private func checkNetworkPermission() {
            let authorization = LocalNetworkAuthorization()
            authorization.requestAuthorization { hasPermission in
                DispatchQueue.main.async {
                    self.showNoNetworkPermissionText = !hasPermission
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
                List {
                    KeyValueProperty(content: device.name, propertyName: NSLocalizedString("ip", comment: "LAN Scanner"))
                        .environment(\.copyToast, $isPresentingToast)
                    if(device.name != device.ipAddress){
                        KeyValueProperty(content: device.ipAddress, propertyName: NSLocalizedString("hostname", comment: "LAN Scanner"))
                            .environment(\.copyToast, $isPresentingToast)
                    }
                    
                    if(device.mac != "02:00:00:00:00:00"){
                        KeyValueProperty(content: device.mac, propertyName: NSLocalizedString("mac", comment: "LAN Scanner"))
                            .environment(\.copyToast, $isPresentingToast)
                    }
                    
                    if(device.brand != ""){
                        KeyValueProperty(content: device.brand, propertyName: NSLocalizedString("brand", comment: "LAN Scanner"))
                            .environment(\.copyToast, $isPresentingToast)
                    }
                    
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
    @Published var scanning = false

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

@available(iOS 14.0, *)
public class LocalNetworkAuthorization: NSObject {
    private var browser: NWBrowser?
    private var netService: NetService?
    private var completion: ((Bool) -> Void)?
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        // Create parameters, and allow browsing over peer-to-peer link.
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // Browse for a custom service type.
        let browser = NWBrowser(for: .bonjour(type: "_bonjour._tcp", domain: nil), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                print(error.localizedDescription)
            case .ready, .cancelled:
                break
            case let .waiting(error):
                print("Local network permission has been denied: \(error)")
                self.reset()
                self.completion?(false)
            default:
                break
            }
        }
        
        self.netService = NetService(domain: "local.", type:"_lnp._tcp.", name: "LocalNetworkPrivacy", port: 1100)
        self.netService?.delegate = self
        
        self.browser?.start(queue: .main)
        self.netService?.publish()
    }
    
    
    
    private func reset() {
        self.browser?.cancel()
        self.browser = nil
        self.netService?.stop()
        self.netService = nil
    }
}

@available(iOS 14.0, *)
extension LocalNetworkAuthorization : NetServiceDelegate {
    public func netServiceDidPublish(_ sender: NetService) {
        self.reset()
        print("Local network permission has been granted")
        completion?(true)
    }
}
