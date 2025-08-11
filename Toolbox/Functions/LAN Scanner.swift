//
//  LAN Scanner.swift
//  Toolbox
//
//  Created by Christian Nagel on 13.08.23.
//
import SwiftUI
import LanScanner

struct LAN_Scanner: View {
    @ObservedObject var viewModel = LAN_ScannerViewModel()
    @State var showSettings = false
    
    var body: some View {
        ZStack {
            List {
                ForEach(viewModel.connectedDevices) { device in
                        
                    Text(device.name + " (\(device.ipAddress))")
                        .contextMenu {
                            Button(action:{
                                UIPasteboard.general.string = device.ipAddress
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }){
                                Label("Copy", systemImage: "clipboard")
                            }
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
        .sheet(isPresented: $showSettings) {
            Text("Scanning finished")
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

class LAN_ScannerViewModel: ObservableObject, LanScannerDelegate {
    
    @Published var connectedDevices = [LanDevice]()
    @Published var progress: CGFloat = .zero
    @Published var currentIP: String = .init()
    @Published var running = false
    
    private lazy var scanner = LanScanner(delegate: self)
    
    func start() {
        withAnimation{
            connectedDevices.removeAll()
        }
        scanner.start()
        withAnimation{
            running = true
        }
    }
    
    func stop() {
        scanner.stop()
        withAnimation{
            running = false
        }
    }
    
    func lanScanHasUpdatedProgress(_ progress: CGFloat, address: String) {
        self.progress = progress
        self.currentIP = address
    }
    
    func lanScanDidFindNewDevice(_ device: LanDevice) {
        connectedDevices.append(device)
    }
    
    func lanScanDidFinishScanning() {
        withAnimation{
            running = false
        }
    }
}

extension LanDevice: @retroactive Identifiable {
    public var id: UUID { .init() }
}

#Preview {
    LAN_Scanner()
}
