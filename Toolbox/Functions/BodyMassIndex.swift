//
//  BodyMassIndex.swift
//  Toolbox
//
//  Created by Christian Nagel on 10.04.22.
//

import SwiftUI
import Combine

struct BodyMassIndex: View {
    
    let metric = Locale.current.measurementSystem == "Metric"
    let defaults = UserDefaults.standard
    
    @State var height = ""
    @State var weight = ""
    
    @State var h:Double = 0
    @State var w:Double = 0
    
    
    
    var body: some View {
        Form{
            HStack{
                Text("Height")
                TextField("", text: $height)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .onReceive(Just(height)) { newValue in
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if filtered != newValue {
                            self.height = filtered
                        }
                        if metric {
                            h = Double(height) ?? 0
                            h = h/100
                        } else {
                            h = Double(height) ?? 0
                        }
                        defaults.set(height, forKey: "bmiHeight")
                        defaults.set(h, forKey: "bmiHeightD")
                        
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }
                    
                Text(metric ? "cm" : "inch")

                
            }

            HStack{
                Text("Weight")
                TextField("", text: $weight)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .onReceive(Just(weight)) { newValue in
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if filtered != newValue {
                            self.weight = filtered
                        }
                        w = Double(weight) ?? 0
                        defaults.set(weight, forKey: "bmiWeight")
                        defaults.set(w, forKey: "bmiWeightD")
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }
                
                
                Text(metric ? "kg" : "lb")
            }
            Section{
                HStack {
                    Text("BMI")
                    Spacer()
                    Text(metric ? String(Double(w/(h*h)).rounded(toPlaces: 2)) : String(Double(w/(h*h)*703).rounded(toPlaces: 2)))
                }
                if metric {
                    if (18.5 >= Double(w/(h*h))) {
                        Text("Underweight")
                            .bold()
                        .foregroundColor(.red)
                    }else if (24.9 >= Double(w/(h*h))) {
                        Text("Normal weight")
                            .bold()
                            .foregroundColor(.green)
                    }else if (29.9 >= Double(w/(h*h))) {
                        Text("Overweight")
                            .bold()
                            .foregroundColor(.orange)
                    }else if (30 <= Double(w/(h*h))){
                        Text("Obese")
                            .bold()
                            .foregroundColor(.red)
                    }
                }else {
                    if (18.5 >= Double(w/(h*h)*703)) {
                        Text("Underweight")
                            .bold()
                            .foregroundColor(.red)
                    }else if (24.9 >= Double(w/(h*h)*703)) {
                        Text("Normal weight")
                            .bold()
                            .foregroundColor(.green)
                    }else if (29.9 >= Double(w/(h*h)*703)) {
                        Text("Overweight")
                            .bold()
                            .foregroundColor(.orange)
                    }else if (30 <= Double(w/(h*h)*703)){
                        Text("Obese")
                            .bold()
                            .foregroundColor(.red)
                    }
                }
                
            }
            Button("More Information") {
                UIApplication.shared.open(URL(string: "https://wikipedia.org/wiki/Body_mass_index")!, options: [:])
            }
        }
        
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("BMI")
        .onAppear(){
            if(defaults.valueExists(forKey: "bmiHeight")){
                height = defaults.string(forKey: "bmiHeight")!
            }
            if(defaults.valueExists(forKey: "bmiWeight")){
                weight = defaults.string(forKey: "bmiWeight")!
            }
            if(defaults.valueExists(forKey: "bmiHeightD")){
                h = defaults.double(forKey: "bmiHeightD")
            }
            if(defaults.valueExists(forKey: "bmiWeightD")){
                w = defaults.double(forKey: "bmiWeightD")
            }
        }
    
    }
    
}

struct BodyMassIndex_Previews: PreviewProvider {
    static var previews: some View {
        BodyMassIndex()
    }
}

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

/// BMI Infos: https://www.freebmicalculator.net/calculate-bmi.php
