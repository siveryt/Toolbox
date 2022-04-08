//
//  Dice.swift
//  Toolbox
//
//  Created by Christian Nagel on 17.03.22.
//

import SwiftUI
import Haptica

struct Dice_Previews: PreviewProvider {
    static var previews: some View {
        DiceView().previewDevice("iPhone 13").environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

struct ShakableViewRepresentable: UIViewControllerRepresentable {
    let onShake: () -> ()
    
    class ShakeableViewController: UIViewController {
        var onShake: (() -> ())?
        
        override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake {
                onShake?()
            }
        }
    }
    
    func makeUIViewController(context: Context) -> ShakeableViewController {
        let controller = ShakeableViewController()
        controller.onShake = onShake
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ShakeableViewController, context: Context) {}
}

extension View {
    func onShake(_ block: @escaping () -> Void) -> some View {
        overlay(
            ShakableViewRepresentable(onShake: block).allowsHitTesting(false)
        )
    }
}

struct DiceView: View {
    
    @State var rolled = "1"
    
    func roll(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            rolled = String(Int.random(in: 1...6))
            Haptic.impact(.light).generate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            rolled = String(Int.random(in: 1...6))
            Haptic.impact(.light).generate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            rolled = String(Int.random(in: 1...6))
            Haptic.impact(.light).generate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            rolled = String(Int.random(in: 1...6))
            Haptic.impact(.light).generate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            rolled = String(Int.random(in: 1...6))
            Haptic.impact(.light).generate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            rolled = String(Int.random(in: 1...6))
            Haptic.impact(.light).generate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            rolled = String(Int.random(in: 1...6))
            Haptic.impact(.light).generate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            rolled = String(Int.random(in: 1...6))
            Haptic.impact(.light).generate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            rolled = String(Int.random(in: 1...6))
            Haptic.impact(.light).generate()
        }
    }
    
    var body: some View {
        VStack{
            Image("dice-"+rolled).resizable()
                .scaledToFit()
                .frame(width: 250.0, height: 250.0, alignment: .top)
                .onTapGesture {
                    roll()
                }
//            Button("Roll!"){
//                roll()
//            }.foregroundColor(.primary)
//                .dynamicTypeSize(/*@START_MENU_TOKEN@*/.xxxLarge/*@END_MENU_TOKEN@*/)
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Dice")
//        .toolbar {
//            Text("Dice")
//        }
//        .navigationTitle("Dice")
        .onShake{
            roll()
        }
    }
    
}
