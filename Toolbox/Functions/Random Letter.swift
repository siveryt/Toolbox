//
//  Random Letter.swift
//  Toolbox
//
//  Created by Christian Nagel on 13.08.23.
//

import SwiftUI
import Haptica

struct Random_Letter: View {
    
    @AppStorage("randomLetter") var letter: String = "Z"
    
    var body: some View {
        Button(action: {
            for dqI in 1...9 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                    letter = String("ABCDEFGHIJKLMNOPQRSTUVWXYZ".randomElement() ?? "Z")
                    Haptic.impact(.light).generate()
                }
            }
            
        }) {
            Text(letter)
                .font(.system(size: UIScreen.main.bounds.width * 0.4)) // Set font size to 30% of screen width
                .background(Color.clear) // Transparent background
                .padding(50) // Add padding to increase the hitbox
        }
        .buttonStyle(PlainButtonStyle())
        .tint(.primary)
        .onShake{
            for dqI in 1...9 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                    letter = String("ABCDEFGHIJKLMNOPQRSTUVWXYZ".randomElement() ?? "Z")
                    Haptic.impact(.light).generate()
                }
            }
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Random Letter")
    }
}

struct Random_Letter_Previews: PreviewProvider {
    static var previews: some View {
        Random_Letter().previewInterfaceOrientation(.landscapeLeft).previewDevice("iPad Pro (12.9-inch) (6th generation)")
    }
}
