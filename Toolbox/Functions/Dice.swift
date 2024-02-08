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

struct DieView: View {
    var number: String
    var sides: Int
    var index: Int
    
    @AppStorage("diceKept") var kept:[Int] = []
    @AppStorage("diceCount") var diceCount = 1
    @AppStorage("diceRolled") var rolled = ["1", "1", "2", "3", "4", "4", "4", "2", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"]
    @AppStorage("diceGuidance") var guidance = true
    
    func roll(){
        
        if(kept.count >= diceCount) {return};
        
        for dqI in 1...9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                let oldRolled = rolled
                rolled = []
                for diceNr in 0...32 {
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
        Image("\(sides)-\(number)")
            .resizable()
            .aspectRatio(1, contentMode: .fit)
        
            .overlay(
                HStack {
                    VStack {
                        if(kept.contains(index)) {
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
                toggleKeep(index: index)
            }
    }
}

struct DiceGridView: View {
    var diceCount: Int
    var faces: [String]
    var sides: Int
    
    

    
    private var columns: [GridItem] {
        let screenWidth = UIScreen.main.bounds.width
        let columnWidth = (screenWidth / 2  - 20) // Adjust the divisor here for the number of columns you want
        return Array(repeating: .init(.fixed(columnWidth)), count: diceCount == 1 ? 1 : 2)
    }
    
    private var size: CGFloat {
        var size = UIScreen.main.bounds.width
        if (diceCount != 1) {
            size = size / 2 - 20
        } else {
            size -= 40
        }
        
        return size
    }
    
    var body: some View {
        
        if((size + 40) * CGFloat(diceCount) > UIScreen.main.bounds.height*2) {
            ScrollView {
                // Your content goes here
                LazyVGrid(columns: columns, alignment: .center) { // Set spacing to 0 if you don't want any space between the dice
                    ForEach(1...diceCount, id: \.self) { i in
                        DieView(number: faces[i], sides: sides, index: i)  // This will cycle through 1 to 6 for the dice numbers
                            .frame(width: size, height: size) // Enforce the dice to be square and fill the column width
                            //.padding([.bottom], 10)
                    }
                }
            }
        } else {
            LazyVGrid(columns: columns, alignment: .center) { // Set spacing to 0 if you don't want any space between the dice
                ForEach(1...diceCount, id: \.self) { i in
                    DieView(number: faces[i], sides: sides, index: i)  // This will cycle through 1 to 6 for the dice numbers
                        .frame(width: size, height: size) // Enforce the dice to be square and fill the column width
                        //.padding([.bottom], 10)
                }
            }
        }
            
        
    }
}


struct DiceView: View {
    
    @AppStorage("diceRolled") var rolled = ["1", "1", "2", "3", "4", "4", "4", "2", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"]
    @AppStorage("diceGuidance") var guidance = true
    @State var settingsSheet = false
    @AppStorage("diceSides") var sides = 6
    @AppStorage("diceCount") var diceCount = 1
    @AppStorage("diceKept") var kept:[Int] = []
    @AppStorage("diceIdleTimerDisabled") var idleTimerDisabled = true
    
    
    
    func roll(){
        
        if(kept.count >= diceCount) {return};
        
        for dqI in 1...9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                let oldRolled = rolled
                rolled = []
                for diceNr in 0...32 {
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
    


    
    
    
    var body: some View {
        
        let sidesBinding = Binding<Int>(get: {
            self.sides
        }, set: {
            
                self.sides = $0
            self.kept = []
            
            roll()
            
        })
        
        VStack {
            DiceGridView(diceCount: diceCount, faces: rolled, sides: sides)

            if guidance {
                Text("Shake or tap to get started").foregroundColor(.secondary)
            }
        }
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
                        Stepper("Dice Count:", value: $diceCount, in: 1...32)
                        Text(String(diceCount))
                    }
                    Section {
                        Toggle(isOn: $idleTimerDisabled) {
                                Text("Disable auto lock")
                        }.onChange(of: idleTimerDisabled) {
                            UIApplication.shared.isIdleTimerDisabled = idleTimerDisabled
                        }
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
        .onAppear()  {
            UIApplication.shared.isIdleTimerDisabled = idleTimerDisabled
        }
        .onDisappear() {
            UIApplication.shared.isIdleTimerDisabled = false
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
