//
//  Dice.swift
//  Toolbox
//
//  Created by Christian Nagel on 17.03.22.
//

import SwiftUI
import Haptica

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }
    
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

struct Dice_Previews: PreviewProvider {
    static var previews: some View {
        DiceView().previewDevice("iPhone 13")
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
    
    @AppStorage("diceRolled") var rolled = ["1", "1", "2", "3", "4", "4", "4", "2"]
    @AppStorage("diceGuidance") var guidance = true
    @State var settingsSheet = false
    @AppStorage("diceSides") var sides = 6
    @AppStorage("diceCount") var diceCount = 1
    @AppStorage("diceKept") var kept:[Int] = []
    
    
    
    func roll(){
        
        if(kept.count >= diceCount) {return};
        
        for dqI in 1...9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                let oldRolled = rolled
                rolled = []
                for diceNr in 0...8 {
                    if (kept.contains(diceNr)) {
                        rolled.append(oldRolled[diceNr])
                    } else {
                        rolled.append(String(Int.random(in: 1...sides)))
                    }
                }
                Haptic.impact(.light).generate()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(){
                guidance = false
            }
        }
    }
    
    func toggleKeep(index: Int) {
        Haptic.impact(.medium).generate()
        if let existingIndex = kept.firstIndex(of: index) {
            kept.remove(at: existingIndex)
        } else {
            kept.append(index)
        }
    }

    
    
    
    var body: some View {
        
        let sidesBinding = Binding<Int>(get: {
            self.sides
        }, set: {
            
                self.sides = $0
            self.kept = []
            
            roll()
            
        })
        
        VStack {
            LazyVGrid(columns: diceCount > 1 ? [GridItem(), GridItem()] : [GridItem()]) {
                            ForEach(0..<diceCount, id: \.self) { i in
                                if rolled.count > i {
                                    Image(String(sides == 20 || sides == 10 ? 8 : sides) + "-" + rolled[i])
                                        .resizable()
                                        .scaledToFit()
                                        
                                        .overlay(
                                            HStack {
                                                VStack {
                                                    if(kept.contains(i)) {
                                                        diceLock()
                                                    }
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                                        )
                                        .onTapGesture {
                                            roll()
                                        }
                                        .onLongPressGesture {
                                            toggleKeep(index: i)
                                        }
                                }
                            }
                        }

            if guidance {
                Text("Shake or tap to get started").foregroundColor(.secondary)
            }
        }
        .padding(.all, 50.0)
        .frame(maxWidth: 500)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Dice")

        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    settingsSheet = true
                }, label: {
                    Image(systemName: "gear")
                })
            }
        }
       
        .onShake{
            roll()
        }

        .sheet(isPresented: $settingsSheet){
            NavigationView {
                
                Form {
                    Picker(selection: sidesBinding, label: Text("Sides:")) {
                        Text("4").tag(4)
                        Text("6").tag(6)
                        Text("8").tag(8)
                        Text("10").tag(10)
                        Text("12").tag(12)
                        Text("20").tag(20)
                    }
                    .pickerStyle(.menu)
                    
                    
                    
                    HStack {
                        Stepper("Dice Count:", value: $diceCount, in: 1...8)
                        Text(String(diceCount))
                    }
                    Section("Hint: You can hold one dice to lock it"){
                        
                    }
                    
                    
                    
                }
                .navigationBarTitle("Dice Settings")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing:
                                        Button("Done") {
                    settingsSheet = false
                }
                )
                
            }
        }
    }
    
}


struct diceLock: View {
    var body: some View{
        Image(systemName: "lock.fill")
            .font(.system(size: 30))
            .foregroundStyle(Color.accentColor)
    }
}
