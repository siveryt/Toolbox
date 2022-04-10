//
//  NFCTools.swift
//  Toolbox
//
//  Created by Christian Nagel on 10.04.22.
//

import SwiftUI

enum nfcState {
    case read, write
}

struct NFCTools: View {
    let defaults = UserDefaults.standard
    @State var nfcViewState: nfcState = .write
    @State var write = ""
    
    var body: some View {
        Form{
            Picker("", selection: $nfcViewState) {
                Text("Read").tag(nfcState.read)
                Text("Write").tag(nfcState.write)
            }
            .pickerStyle(.segmented)
            if (nfcViewState == .read) {
                
                Section {
                    Button("Read") {
                        print("Read")
                    }
                }
                
                Section {
                    HStack{
                        Text("Identifier")
                        Spacer()
                        Text(UUID().description)
                    }
                    HStack{
                        Text("Content")
                        Spacer()
                        Text("Lorem ipsum.... ")
                    }
                }
                
            } else {
                Section {
                    HStack{
                        Text("Content")
                        TextField("toolbox.sivery.de", text: $write)
                            .onChange(of: write) { value in
                                defaults.set(write, forKey: "nfcContent")
                            }
                            .multilineTextAlignment(.trailing)
                            
                    }
                }
                Section {
                    Button("Write") {
                        print("Write")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("NFC Tools")
        .onAppear(){
            if(defaults.valueExists(forKey: "nfcContent")){
                write = defaults.string(forKey: "nfcContent")!
            }
        }
    }
    
}

struct NFCTools_Previews: PreviewProvider {
    static var previews: some View {
        NFCTools()
    }
}
