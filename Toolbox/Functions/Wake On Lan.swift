//
//  Wake On Lan.swift
//  Toolbox
//
//  Created by Christian Nagel on 21.05.24.
//

import SwiftUI
import SwiftData
import Awake
import Combine
import SystemConfiguration

struct Wake_On_Lan: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \WOLDevice.lastUsed, order: .reverse) var devices: [WOLDevice]
    
    @State var selectedDevice: Awake.Device? = nil
    @State var wakeAlertPresented = false
    @State var sheetDisplayed = false
    @State var editing = false
    
    @State var invalid_name_empty = true
    @State var invalid_name_same = false
    @State var invalid_mac_empty = true
    @State var invalid_mac_warning = false
    @State var invalid_broadcast_empty = false
    @State var invalid_port_empty = false
    @State var invalid_port_warning = false
    
    @State var sheet_name_editOriginal = ""
    @State var sheet_name = ""
    @State var sheet_mac = ""
    @State var sheet_broadcast = ""
    @State var sheet_port = "9"
    @State var sheet_editDevice:WOLDevice? = nil
    
    var body: some View {
        List {
            ForEach(devices) { device in
                Button(device.name, action: {
                    selectedDevice = Awake.Device(MAC: device.mac, BroadcastAddr: device.broadcast, Port: UInt16(device.port ?? 9))
                    sheet_editDevice = device
                    wakeAlertPresented = true
                })
                .tint(.primary)
                .swipeActions(edge: .leading, allowsFullSwipe: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/) {
                    Button {
                        print("\(device.name) swiped")
                        selectedDevice = Awake.Device(MAC: device.mac, BroadcastAddr: device.broadcast, Port: UInt16(device.port ?? 9))
                        withAnimation { ///Why doesnt this animate? 
                            device.lastUsed = Date()
                        }
                        wake()
                    } label: {
                        Text("Wake")
                    }
                    .tint(.accentColor)
                }
                
                .contextMenu {
                    Button(action:{
                        sheet_name = device.name
                        sheet_name_editOriginal = device.name
                        sheet_mac = device.mac
                        sheet_broadcast = device.broadcast
                        sheet_port = String(device.port ?? 9)
                        sheet_editDevice = device
                        editing = true
                        sheetDisplayed = true
                        print(device.id)
                    }){
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action:{
                        withAnimation(){
                            modelContext.delete(device)
                        }
                    }){
                        Label("Delete", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }

            }
            .onDelete(perform: delete)
        }
        .sheet(isPresented: $sheetDisplayed, content: {
            NavigationView {
                Form {
                    Section {
                        VStack {
                            HStack {
                                Text("Name")
                                Spacer()
                                TextField("Device Name", text: $sheet_name)
                                    .multilineTextAlignment(.trailing)
                                    .onReceive(Just(sheet_name)) { new_value in
                                        invalid_name_empty = sheet_name == ""
                                        invalid_name_same = (editing && sheet_name == sheet_name_editOriginal) ? false : devices.contains {$0.name == sheet_name}
                                    }
                                    .onReceive(NotificationCenter.default.publisher(
                                        for: UITextField.textDidBeginEditingNotification)) { _ in
                                            DispatchQueue.main.async {
                                                UIApplication.shared.sendAction(
                                                    #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                                                )
                                            }
                                        }
                            }
                            if(invalid_name_empty) {
                                HStack{
                                    Text("You can't leave the name empty")
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                    Spacer()
                                }
                            }
                            if(invalid_name_same) {
                                HStack{
                                    Text("You can't use the same name twice")
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                    Spacer()
                                }
                            }
                        }
                    }
                    VStack {
                        HStack {
                            Text("MAC")
                            Spacer()
                            TextField("00:1A:2B:3C:4D:5E", text: $sheet_mac)
                                .multilineTextAlignment(.trailing)
                                .onReceive(Just(sheet_mac)) { new_value in
                                    invalid_mac_empty = sheet_mac == ""
                                    invalid_mac_warning = !isValidMACAddress(sheet_mac)
                                }
                                .onReceive(NotificationCenter.default.publisher(
                                    for: UITextField.textDidBeginEditingNotification)) { _ in
                                        DispatchQueue.main.async {
                                            UIApplication.shared.sendAction(
                                                #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                                            )
                                        }
                                    }
                        }
                        if(invalid_mac_empty) {
                            HStack{
                                Text("You can't leave the MAC empty")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                        }
                        if(invalid_mac_warning && !invalid_mac_empty) {
                            HStack{
                                Text("Make sure you entered in the right value")
                                    .font(.footnote)
                                    .foregroundStyle(.yellow)
                                Spacer()
                            }
                        }
                    }
                    VStack{
                        HStack {
                            Text("Broadcast")
                            Spacer()
                            TextField("255.255.255.255", text: $sheet_broadcast)
                                .multilineTextAlignment(.trailing)
                                .onReceive(Just(sheet_broadcast)) { new_value in
                                    invalid_broadcast_empty = sheet_broadcast == ""
                                }
                                .onReceive(NotificationCenter.default.publisher(
                                    for: UITextField.textDidBeginEditingNotification)) { _ in
                                        DispatchQueue.main.async {
                                            UIApplication.shared.sendAction(
                                                #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                                            )
                                        }
                                    }
                        }
                        if(invalid_broadcast_empty) {
                            HStack{
                                Text("You can't leave the Broadcast empty")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                        }
                    }
                    VStack {
                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("9", text: $sheet_port)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .onReceive(Just(sheet_port)) { newValue in
                                    let filtered = newValue.filter { "0123456789".contains($0) }
                                    if filtered != newValue {
                                        self.sheet_port = filtered
                                    }
                                    
                                    invalid_port_empty = sheet_port == ""
                                    invalid_port_warning = Int(sheet_port) ?? 0 > 65535
                                }
                                .onReceive(NotificationCenter.default.publisher(
                                    for: UITextField.textDidBeginEditingNotification)) { _ in
                                        DispatchQueue.main.async {
                                            UIApplication.shared.sendAction(
                                                #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                                            )
                                        }
                                    }
                        }
                        if(invalid_port_empty) {
                            HStack{
                                Text("You can't leave the port empty")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                        }
                        if(invalid_port_warning) {
                            HStack{
                                Text("Make sure you entered in the right value")
                                    .font(.footnote)
                                    .foregroundStyle(.yellow)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationBarTitle("Add new Device")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(leading:
                                        Button("Cancel") {
                    resetSheetData()
                    sheetDisplayed = false
                }, trailing:
                                        Button("Done") {
                    sheet_mac = sheet_mac.replacingOccurrences(of: "-", with: ":")
                    if(editing && sheet_editDevice != nil) {
                        sheet_editDevice!.mac = sheet_mac
                        sheet_editDevice!.name = sheet_name
                        sheet_editDevice!.port = Int(sheet_port)
                        sheet_editDevice!.broadcast = sheet_broadcast
                    } else {
                        modelContext.insert(WOLDevice(name: sheet_name, mac: sheet_mac, broadcast: sheet_broadcast, port: Int(sheet_port) ?? 9))
                    }
                    sheetDisplayed = false
                    editing = false
                    resetSheetData()
                }
                    .disabled(invalid_mac_empty || invalid_name_same || invalid_name_empty || invalid_port_empty || invalid_broadcast_empty)
                )
            }
        })
        .navigationBarTitle("Wake On Lan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(action: {
                resetSheetData()
                sheetDisplayed = true
            }, label: {
                Image(systemName: "plus")
            })
        }
        .alert(isPresented: $wakeAlertPresented, content: {
            Alert(title: Text("Are you sure you want to start the device?"),
                  primaryButton: .cancel(),
                  secondaryButton: .default(Text("Yes")) {
                wake()
                if (sheet_editDevice != nil) {
                    withAnimation {
                        sheet_editDevice!.lastUsed = Date()
                    }
                }
                sheet_editDevice = nil
            })
        })
    }
    
    func delete(_ indexSet: IndexSet) {
        for index in indexSet {
            let device = devices[index]
            modelContext.delete(device)
        }
    }
    
    func wake() {
        if(selectedDevice != nil) {
            print("Waking \(selectedDevice.debugDescription)")
            let result = Awake.target(device: selectedDevice!)
            if (result != nil) {
                print(result!.localizedDescription)
                /// Todo: alert the error
            }
        } else {
            print("Requested device is nil :panic:")
        }
    }
    
    func isValidMACAddress(_ macAddress: String) -> Bool {
        // Define the regular expression pattern for a MAC address
        let macAddressRegex = "([0-9A-Fa-f]{2}([-:])){5}([0-9A-Fa-f]{2})"
        
        // Create a predicate with the regular expression
        let predicate = NSPredicate(format: "SELF MATCHES %@", macAddressRegex)
        
        // Evaluate the string with the predicate
        return predicate.evaluate(with: macAddress)
    }
    
    func resetSheetData() {
        invalid_name_empty = true
        invalid_name_same = false
        invalid_mac_empty = true
        invalid_mac_warning = false
        invalid_broadcast_empty = false
        invalid_port_empty = false
        invalid_port_warning = false
        
        sheet_name = ""
        sheet_mac = ""
        sheet_broadcast = getBroadcast() ?? ""
        sheet_port = "9"
        sheet_editDevice = nil
        sheet_name_editOriginal = ""
    }
    
    func getBroadcast() -> String? {
        var networkDetails: [(interfaceName: String, ipAddress: String, broadcastAddress: String)] = []

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr else { return nil }
                
                let flags = Int32(interface.pointee.ifa_flags)
                let addr = interface.pointee.ifa_addr.pointee
                
                // Check for IPv4 and running interfaces
                if addr.sa_family == UInt8(AF_INET) && (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    var net = interface.pointee.ifa_netmask.pointee
                    var ifa_addr = interface.pointee.ifa_addr.pointee
                    
                    let ip4Addr = withUnsafePointer(to: &ifa_addr) {
                        $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                    }
                    let netmask = withUnsafePointer(to: &net) {
                        $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                    }

                    // Calculate broadcast address
                    let ip4Address = ip4Addr.s_addr
                    let netmaskAddress = netmask.s_addr
                    let broadcastAddress = ip4Address | ~netmaskAddress
                    
                    let broadcastAddr = in_addr(s_addr: broadcastAddress)
                    let broadcastAddrStr = String(cString: inet_ntoa(broadcastAddr))
                    let ipAddressStr = String(cString: inet_ntoa(ip4Addr))
                    let interfaceName = String(cString: interface.pointee.ifa_name)
                    
                    networkDetails.append((interfaceName, ipAddressStr, broadcastAddrStr))
                }
            }
            freeifaddrs(ifaddr)
        }
        
        // Look for the main interface, commonly 'en0' for Wi-Fi
        for detail in networkDetails {
            if detail.interfaceName == "en0" {
                return detail.broadcastAddress
            }
        }
        
        return nil
    }
}

#Preview {
    Wake_On_Lan()
}
