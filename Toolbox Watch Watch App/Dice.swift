//
//  Dice.swift
//  Toolbox Watch Watch App
//
//  Created by Christian Nagel on 04.11.22.
//

import SwiftUI

struct Dice: View {
    
    @AppStorage("rolled") var rolled = 4
    
    var body: some View {
        Image("dice-\(rolled)")
            .resizable()
            .scaledToFit()
            .onTapGesture {
                for dqI in 1...9 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                        for _ in 0...8 {
                            rolled = Int.random(in: 1...6)
                        }
                        WKInterfaceDevice.current().play(.click)
                    }
                }
            }
        
            
    }
}
