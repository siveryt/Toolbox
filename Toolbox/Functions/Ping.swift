//
//  Ping.swift
//  Toolbox
//
//  Created by Christian Nagel on 05.11.22.
//

import SwiftUI
import SwiftyPing

struct Ping: View {
    @AppStorage("pingHost") var host = ""
    //    @AppStorage("pingInterval") var interval = ""
    //    @AppStorage("pingRepeats") var repeats = ""
    /// Result of the last ping in ms, nil while there is none.
    @State var result: Int? = nil
    /// The last ping got no answer (timeout) or couldn't be sent.
    @State var lastPingFailed: PingError? = nil
    @State var max: Int? = nil
    @State var calculating = false
    @State var errorMessage: String? = nil
    @State var pinger: SwiftyPing? = nil
    /// Identifies the current run, so callbacks from a stopped pinger are ignored.
    @State var generation = 0
    
    var body: some View {
        Form {
            Section() {
                HStack {
                    Text("Host")
                    TextField("toolbox.sivery.de", text: $host)
                        .keyboardType(/*@START_MENU_TOKEN@*/.URL/*@END_MENU_TOKEN@*/)
                        .textCase(/*@START_MENU_TOKEN@*/.lowercase/*@END_MENU_TOKEN@*/)
                        .textContentType(/*@START_MENU_TOKEN@*/.URL/*@END_MENU_TOKEN@*/)
                        .autocapitalization(/*@START_MENU_TOKEN@*/.none/*@END_MENU_TOKEN@*/)
                        .multilineTextAlignment(.trailing)
                        .onSubmit(of: /*@START_MENU_TOKEN@*/.text/*@END_MENU_TOKEN@*/) {
                            ping()
                        }
                        .disableAutocorrection(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                        .submitLabel(.go)
                        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                            if let textField = obj.object as? UITextField {
                                textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                            }
                        }
                }
                Button("Again") {
                    ping()
                }
            }
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Time")
                Spacer()
                if(calculating) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(.trailing, 1)
                }
                
                if let lastPingFailed {
                    Text(lastPingFailed == .responseTimeout || lastPingFailed == .requestTimeout
                         ? NSLocalizedString("Timeout", comment: "Ping tool: shown instead of a time when the host didn't answer in time")
                         : NSLocalizedString("Failed", comment: "Ping tool: shown instead of a time when the ping couldn't be sent"))
                } else if let result {
                    Text(String(result) + " ms")
                } else {
                    Text("None")
                }
            }
            HStack {
                Text("Max")
                Spacer()
                if(calculating) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(.trailing, 1)
                }
                
                if let max {
                    Text(String(max) + " ms")
                } else {
                    Text("None")
                }
            }
            
            
        }
        .onAppear(){
            ping()
        }
        .onDisappear() {
            stopPinging()
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Ping")
    }
    
    func stopPinging() {
        generation += 1
        pinger?.haltPinging()
        pinger = nil
        calculating = false
    }
    
    func ping() {
        stopPinging()
        result = nil
        max = nil
        lastPingFailed = nil
        errorMessage = nil
        
        let host = self.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }
        calculating = true
        let current = generation
        
        // SwiftyPing resolves the host synchronously in its initializer, which would block the UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let newPinger = try SwiftyPing(host: host, configuration: PingConfiguration(interval: 0.5, with: 5), queue: DispatchQueue.global())
                newPinger.targetCount = 5
                // The observer is called on the queue above, the UI is updated on the main queue.
                // (Passing .main as queue would deadlock: SwiftyPing calls it with sync from the main run loop.)
                newPinger.observer = { response in
                    DispatchQueue.main.async {
                        guard current == generation else { return }
                        if let error = response.error {
                            lastPingFailed = error
                        } else {
                            let duration = Int(response.duration * 1000)
                            lastPingFailed = nil
                            result = duration
                            if duration > (max ?? -1) {
                                max = duration
                            }
                        }
                    }
                }
                newPinger.finished = { _ in
                    DispatchQueue.main.async {
                        guard current == generation else { return }
                        calculating = false
                        pinger = nil
                    }
                }
                DispatchQueue.main.async {
                    guard current == generation else {
                        // The user started another ping or left in the meantime
                        newPinger.haltPinging()
                        return
                    }
                    pinger = newPinger
                    do {
                        try newPinger.startPinging()
                    } catch {
                        fail(with: error)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard current == generation else { return }
                    fail(with: error)
                }
            }
        }
    }
    
    func fail(with error: Error) {
        pinger?.haltPinging()
        pinger = nil
        calculating = false
        switch error as? PingError {
        case .hostNotFound, .addressLookupError, .unknownHostError:
            errorMessage = NSLocalizedString("Couldn't find this host. Check the address and your internet connection.", comment: "Ping tool: error shown when the host name couldn't be resolved")
        default:
            errorMessage = NSLocalizedString("Couldn't ping this host.", comment: "Ping tool: error shown when pinging failed for another reason than an unknown host")
        }
    }
    
}

struct Ping_Previews: PreviewProvider {
    static var previews: some View {
        Ping()
    }
}
