//
//  LAN Scanner.swift
//  Toolbox
//
//  Created by Christian Nagel on 13.08.23.
//
import SwiftUI
import LanScanner

struct LAN_Scanner: View {
    @StateObject var viewModel = LAN_ScannerViewModel()
    
    var body: some View {
        ZStack {
            List {
                ForEach(viewModel.connectedDevices, id: \.ipAddress) { device in
                        
                    Text(device.name + " (\(device.ipAddress))")
                        .contextMenu {
                            Button(action:{
                                UIPasteboard.general.string = device.ipAddress
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }){
                                Label(NSLocalizedString("Copy", comment: "LAN Scanner: context menu action that copies the IP address of a device"), systemImage: "clipboard")
                            }
                        }
                }
                
            }
            .overlay {
                if viewModel.noWiFi {
                    ContentUnavailableView {
                        Label(NSLocalizedString("No Wi-Fi Connection", comment: "LAN Scanner: empty state title when the device isn't connected to a Wi-Fi network"), systemImage: "wifi.slash")
                    } description: {
                        Text(NSLocalizedString("Connect to a Wi-Fi network to scan it for devices.", comment: "LAN Scanner: empty state explanation when the device isn't connected to a Wi-Fi network"))
                    }
                } else if !viewModel.running && viewModel.connectedDevices.isEmpty {
                    ContentUnavailableView {
                        Label("No Devices Found", systemImage: "network.slash")
                    } description: {
                        Text("Tap \(Image(systemName: "arrow.clockwise")) to scan again. If nothing shows up, check that Toolbox can access your local network in Settings.")
                    }
                }
            }
            
            if viewModel.running {
                VStack{
                    Spacer()
                    VStack {
                        
                        Text(viewModel.currentIP)
                        
                        ProgressView(value: viewModel.progress)
                            .frame(width: 200)
                        
                    }
                    .padding()
                    .containerShape(.capsule)
                    .glassEffect()
                }
                .zIndex(2)
                .transition(.move(edge: .bottom))
                
            }
            
        }
        .onAppear() {
            viewModel.start()
        }
        .onDisappear() {
            viewModel.stop()
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("LAN Scanner")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.running ? viewModel.stop() : viewModel.start()
                }, label: {
                    Image(systemName: viewModel.running ? "stop.fill" : "arrow.clockwise")
                })
            }
        }
    }
}

class LAN_ScannerViewModel: ObservableObject {
    
    @Published var connectedDevices = [LanDevice]()
    @Published var progress: CGFloat = .zero
    @Published var currentIP: String = .init()
    @Published var running = false
    /// There is no IPv4 address on Wi-Fi (en0), so there is nothing to scan.
    @Published var noWiFi = false
    
    /// A new scanner per scan, so results still arriving from a stopped scan are dropped.
    private var scanner: LanScanner?
    /// LanScanner only keeps a weak reference to its delegate.
    private var scanDelegate: LAN_ScanDelegate?
    /// Identifies the current scan; callbacks from older scans are ignored.
    private var generation = 0
    
    func start() {
        stop()
        generation += 1
        let current = generation
        
        withAnimation{
            connectedDevices.removeAll()
            progress = .zero
            currentIP = ""
        }
        // Without Wi-Fi LanScan never starts and never reports that it finished
        guard LAN_ScannerViewModel.hasWiFiAddress() else {
            withAnimation{
                noWiFi = true
            }
            return
        }
        noWiFi = false
        
        let delegate = LAN_ScanDelegate(viewModel: self, generation: current)
        let scanner = LanScanner(delegate: delegate)
        scanDelegate = delegate
        self.scanner = scanner
        scanner.start()
        withAnimation{
            running = true
        }
        
        // Safety net: a full scan takes about 30 seconds, so end it if it never reports back
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self, self.generation == current, self.running else { return }
            self.stop()
        }
    }
    
    func stop() {
        generation += 1
        scanner?.stop()
        scanner = nil
        scanDelegate = nil
        withAnimation{
            running = false
        }
    }
    
    func scanHasUpdatedProgress(_ progress: CGFloat, address: String, generation: Int) {
        guard generation == self.generation else { return }
        self.progress = progress
        self.currentIP = address
    }
    
    func scanDidFindNewDevice(_ device: LanDevice, generation: Int) {
        guard generation == self.generation,
              !connectedDevices.contains(where: { $0.ipAddress == device.ipAddress }) else { return }
        connectedDevices.append(device)
    }
    
    func scanDidFinishScanning(generation: Int) {
        guard generation == self.generation else { return }
        withAnimation{
            running = false
        }
    }
    
    /// Whether Wi-Fi (en0) is up and has an IPv4 address – the network LanScan scans.
    static func hasWiFiAddress() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }
        
        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard String(cString: interface.pointee.ifa_name) == "en0",
                  let addr = interface.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let flags = Int32(interface.pointee.ifa_flags)
            if (flags & (IFF_UP|IFF_RUNNING)) == (IFF_UP|IFF_RUNNING) {
                return true
            }
        }
        return false
    }
}

/// Forwards the callbacks of one scan to the view model, tagged with that scan's generation.
final class LAN_ScanDelegate: LanScannerDelegate {
    weak var viewModel: LAN_ScannerViewModel?
    let generation: Int
    
    init(viewModel: LAN_ScannerViewModel, generation: Int) {
        self.viewModel = viewModel
        self.generation = generation
    }
    
    func lanScanHasUpdatedProgress(_ progress: CGFloat, address: String) {
        DispatchQueue.main.async { [weak viewModel = self.viewModel, generation = self.generation] in
            viewModel?.scanHasUpdatedProgress(progress, address: address, generation: generation)
        }
    }
    
    func lanScanDidFindNewDevice(_ device: LanDevice) {
        DispatchQueue.main.async { [weak viewModel = self.viewModel, generation = self.generation] in
            viewModel?.scanDidFindNewDevice(device, generation: generation)
        }
    }
    
    func lanScanDidFinishScanning() {
        DispatchQueue.main.async { [weak viewModel = self.viewModel, generation = self.generation] in
            viewModel?.scanDidFinishScanning(generation: generation)
        }
    }
}

#Preview {
    LAN_Scanner()
}
