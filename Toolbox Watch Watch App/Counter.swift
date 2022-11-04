//
//  Counter.swift
//  Toolbox Watch Watch App
//
//  Created by Christian Nagel on 04.11.22.
//

import SwiftUI

struct Counter: View {
    
    @AppStorage("counted") var counted = 0
    @State var isPresentingConfirm = false
    
    var body: some View {
        VStack {
            Text(String(counted))
                .font(.largeTitle)
                .padding()
            HStack {
                Button("-") {
                    counted -= 1
                }
                Button(action: {
                    isPresentingConfirm = true
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                Button("+") {
                    counted += 1
                }
                
            }
        }
        .confirmationDialog("Reset counter?", isPresented: $isPresentingConfirm) {
            Button("Reset", role: .destructive) {
                counted = 0
            }
        }
    }
    
}

struct Counter_Previews: PreviewProvider {
    static var previews: some View {
        Counter()
    }
}
