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
    @State var result = 99999999
    @State var max = 99999999
    @State var calculating = false
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
            HStack {
                Text("Time")
                Spacer()
                if(calculating) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(.trailing, 1)
                }
                
                if(result == 99999999) {
                    Text("None")
                } else {
                    Text(String(result) + " ms")
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
                
                if(result == 99999999) {
                    Text("None")
                } else {
                    Text(String(max) + " ms")
                }
            }
            
            
        }
        .onAppear(){
            ping()
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Ping")
    }
    func ping() {
        result = 99999999;
        max = 99999999;
        calculating = true;
        var counted = 0;
        let once = try? SwiftyPing(host: host, configuration: PingConfiguration(interval: 0.5, with: 5), queue: DispatchQueue.global())
        once?.observer = { (response) in
            let duration = response.duration
            result = Int(duration*1000)
            if (result > max || max == 99999999) {
                max = result
            }
            counted += 1;
            if(counted == 5) {
                calculating = false
            }
        }
        once?.targetCount = 5
        try? once?.startPinging()
        
    }
    
}

struct Ping_Previews: PreviewProvider {
    static var previews: some View {
        Ping()
    }
}
