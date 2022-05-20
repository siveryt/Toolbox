//
//  RandomNumber.swift
//  Toolbox
//
//  Created by Christian Nagel on 20.03.22.
//

import SwiftUI
import Haptica

struct RandomNumber: View {
    
    @State var min: Int = 0
    @State var max: Int = 100
    @State var random: String = ""
    
    var body: some View {
        
        let minBinding = Binding<String>(get: {
            String(self.min)
        }, set: {
            self.min = Int($0 == "" ? "0" : $0)!
        })
        let maxBinding = Binding<String>(get: {
            String(self.max)
        }, set: {
            self.max = Int($0 == "" ? "0" : $0)!
        })
        
        VStack {
            HStack{
                Spacer()
                    .padding(.trailing, 1.0)
                TextField("Min", text: minBinding)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(/*@START_MENU_TOKEN@*/.numberPad/*@END_MENU_TOKEN@*/)
                Text("-")
                TextField("Max", text: maxBinding)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(/*@START_MENU_TOKEN@*/.numberPad/*@END_MENU_TOKEN@*/)
                Spacer()
                    .padding(.trailing, 1.0)
                
            }
            if(min < max){
                Text(String(Int.random(in: min ..< max+1)))
                    .dynamicTypeSize(.accessibility2)
                    .onTapGesture {
                        Haptic.impact(.light).generate()
                        min += 1
                        min -= 1
                    }
            }else if (min > max){
                Text(String(Int.random(in: max ..< min+1)))
                    .dynamicTypeSize(.accessibility2)
                    .onTapGesture {
                        Haptic.impact(.light).generate()
                        min += 1
                        min -= 1
                    }
            }else {
                Text(String(min))
                    .dynamicTypeSize(.accessibility2)
            }
            
                
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Random Number")
    }
}

struct RandomNumber_Previews: PreviewProvider {
    static var previews: some View {
        RandomNumber()
    }
}
