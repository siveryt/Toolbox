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
        
        // Locks on dice beyond the current count don't count, every visible die locked means there's nothing to roll
        if(kept.filter { $0 <= diceCount }.count >= diceCount) {return};
        
        for dqI in 1...9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                rolled = DiceView.rerolled(rolled, kept: kept, sides: sides)
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
        Image("\(sides == 20 || sides == 10 ? 8 : sides)-\(number)")
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
    
    private let spacing: CGFloat = 20
    
    /// Picks the column count that gives the biggest dice while all of them still fit the available width and height.
    private func layout(for containerSize: CGSize) -> (columns: Int, dieSize: CGFloat) {
        let width = containerSize.width - 2 * spacing
        let height = containerSize.height - 2 * spacing
        var best = (columns: 1, dieSize: CGFloat(0))
        
        for columns in 1...diceCount {
            let rows = Int((Double(diceCount) / Double(columns)).rounded(.up))
            let fittingWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            let fittingHeight = (height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
            let dieSize = min(fittingWidth, fittingHeight)
            if dieSize > best.dieSize {
                best = (columns, dieSize)
            }
        }
        return best
    }
    
    var body: some View {
        
        GeometryReader { geometry in
            let layout = layout(for: geometry.size)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(layout.dieSize), spacing: spacing), count: layout.columns), spacing: spacing) {
                ForEach(1...diceCount, id: \.self) { i in
                    DieView(number: faces.indices.contains(i) ? faces[i] : "1", sides: sides, index: i)
                        .frame(width: layout.dieSize, height: layout.dieSize)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .avoidingActiveDivision()
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
    
    
    
    /// New faces for all 32 dice (index 0 is unused, the dice are numbered from 1); locked dice keep their face.
    /// Older or default arrays can be shorter, so locked dice without a stored face are rolled too.
    static func rerolled(_ old: [String], kept: [Int], sides: Int) -> [String] {
        (0...32).map { diceNr in
            if kept.contains(diceNr), old.indices.contains(diceNr) {
                return old[diceNr]
            }
            return String(Int.random(in: 1...sides))
        }
    }
    
    func roll(max: Int, instant: Bool = false){
        
        // Locks on dice beyond the current count don't count, every visible die locked means there's nothing to roll
        if (kept.filter { $0 <= diceCount }.count >= diceCount) {return};
        
        if (instant) {
            rolled = (0...32).map { _ in String(Int.random(in: 1...max)) }
            return;
        }
        
        for dqI in 1...9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                rolled = DiceView.rerolled(rolled, kept: kept, sides: max)
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
            roll(max: $0, instant: true)
            
            self.sides = $0
            self.kept = []
            
            
            
        })
        
        VStack {
            DiceGridView(diceCount: diceCount, faces: rolled, sides: sides)
            if guidance {
                Text("Shake or Tap to Get Started").foregroundColor(.secondary)
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
            roll(max: sides)
        }

        .sheet(isPresented: $settingsSheet){
            NavigationStack {
                
                Form {
                    Picker(selection: sidesBinding, label: Text("Sides")) {
                        Text("4").tag(4)
                        Text("6").tag(6)
                        Text("8").tag(8)
                        Text("10").tag(10)
                        Text("12").tag(12)
                        Text("20").tag(20)
                    }
                    .pickerStyle(.menu)
                    
                    
                    
                    Stepper(value: $diceCount, in: 1...32) {
                        HStack {
                            Text("Dice Count")
                            Spacer()
                            Text(diceCount, format: .number)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText(value: Double(diceCount)))
                                .animation(.snappy, value: diceCount)
                                .padding(.trailing, 12)
                        }
                    }
                    Section {
                        Toggle(isOn: $idleTimerDisabled) {
                                Text("Disable Auto Lock")
                        }.onChange(of: idleTimerDisabled) {
                            UIApplication.shared.isIdleTimerDisabled = idleTimerDisabled
                        }
                    }

                    Section(NSLocalizedString("Hint: You can hold a die to lock it", comment: "Dice settings: hint below the settings that a long press on a die locks it")){

                    }




                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button(role: .close) {
                        settingsSheet = false
                    }
                }
            }
        }
        // Locks on dice that are no longer shown would otherwise block rolling
        .onChange(of: diceCount) {
            kept.removeAll { $0 > diceCount }
        }
        .onAppear()  {
            UIApplication.shared.isIdleTimerDisabled = idleTimerDisabled
            kept.removeAll { $0 > diceCount }
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
