//
//  Random Number.swift
//  Toolbox Watch Watch App
//
//  Created by Christian Nagel on 04.11.22.
//

import SwiftUI
import SwiftUI_Apple_Watch_Decimal_Pad

struct Random_Number: View {
    
    @AppStorage("randomNumber") var generated = 87
    @AppStorage("from") var from = "0"
    @AppStorage("to") var to = "100"
    @State public var presentingModal: Bool = false
    @State var options = false
    
    var body: some View {
        VStack {
            Text(String(generated))
                .font(.largeTitle)
                .padding()
            Button("Again") { generateNumber() }
            Button("Options") { options = true }
        }
        .sheet(isPresented: $options) {
            VStack{
                VStack {
                    HStack {
                        Text("From")
                        Spacer()
                    }
                    DigiTextView(placeholder: "From",
                                 text: $from,
                                 presentingModal: presentingModal,
                                 alignment: .leading
                    )
                }
                VStack {
                    HStack {
                        Text("To")
                        Spacer()
                    }
                    DigiTextView(placeholder: "To",
                                 text: $to,
                                 presentingModal: presentingModal,
                                 alignment: .leading
                    )
                }
            }
            
        }
    }
    
    func generateNumber() {
        let min = Int(from) ?? 0
        let max = Int(to) ?? 100
        if(min < max){
            generated = Int.random(in: min ..< max+1)
        }else if (min > max){
            generated = Int.random(in: max ..< min+1)
        }else {
            generated = min
        }
    }
}

struct Random_Number_Previews: PreviewProvider {
    static var previews: some View {
        Random_Number()
    }
}
