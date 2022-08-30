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
    
    @AppStorage("diceRolled") var rolled = ["1", "1", "2", "3", "4", "4", "4", "2"]
    @AppStorage("diceGuidance") var guidance = true
    @State var settingsSheet = false
    @AppStorage("diceSides") var sides = 6
    @AppStorage("diceCount") var diceCount = 1
    
    
    
    func roll(){
        
        for dqI in 1...9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                rolled = []
                for _ in 0...8 {
                    rolled.append(String(Int.random(in: 1...sides)))
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
    
    
    
    var body: some View {
        
        let sidesBinding = Binding<Int>(get: {
            self.sides
        }, set: {
            
                self.sides = $0
            
            roll()
            
        })
        
        VStack{
            LazyVGrid(columns: diceCount > 1 ? [GridItem(), GridItem()] : [GridItem()]) {
                ForEach(0..<diceCount, id: \.self) {i in
                    Image(String(sides)+"-"+rolled[i])
                        .resizable()
                        .scaledToFit()
                        
                }
                
            }
            
            
            if guidance {
                Text("Shake or tap to get started").foregroundColor(.secondary)
            }
        }
        .onTapGesture {
            roll()
        }
        .padding(.all, 50.0)
        .frame(maxWidth: 500)

        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
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
                        Text("12").tag(12)
                    }
                    .pickerStyle(.menu)
                    
                    
                    
                    HStack {
                        Stepper("Dice Count:", value: $diceCount, in: 1...8)
                        Text(String(diceCount))
                    }
                    
                    
                    
                }
                .navigationBarTitle("Dice Settings")
                .navigationBarTitleDisplayMode(.large)
                .navigationBarItems(trailing:
                                        Button("Done") {
                    settingsSheet = false
                }
                )
                
            }
        }
    }
    
}

