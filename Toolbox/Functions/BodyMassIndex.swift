//
//  BodyMassIndex.swift
//  Toolbox
//
//  Created by Christian Nagel on 10.04.22.
//

import SwiftUI
import Combine

struct BodyMassIndex: View {

    let metric = Locale.current.measurementSystem == .metric
    let defaults = UserDefaults.standard

    @State var height = ""
    @State var weight = ""
    @State var waist = ""

    @State var h:Double = 0
    @State var w:Double = 0

    var bmi: Double? {
        guard h > 0, w > 0 else { return nil }
        return metric ? w/(h*h) : w/(h*h)*703
    }

    /// Waist and height are entered in the same unit, so the ratio needs no conversion
    var waistToHeight: Double? {
        guard let waist = parse(waist), let height = parse(height), waist > 0, height > 0 else { return nil }
        return waist/height
    }

    /// The decimal separator of the user's region ("," in German), the one the decimal pad shows
    let decimalSeparator = Locale.current.decimalSeparator ?? "."

    /// Keeps digits and a single decimal separator; "." and "," both count as the separator, so pasted values work too
    func sanitize(_ text: String) -> String {
        var result = ""
        var hasSeparator = false
        for character in text {
            if character.isASCII && character.isNumber {
                result.append(character)
            } else if (character == "." || character == "," || String(character) == decimalSeparator) && !hasSeparator {
                result += decimalSeparator
                hasSeparator = true
            }
        }
        return result
    }

    /// Parses a sanitized input such as "72,5" with the current locale's decimal separator
    func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: decimalSeparator, with: "."))
    }

    func format(_ value: Double?) -> String {
        value?.formatted(.number.precision(.fractionLength(2))) ?? "–"
    }

    var body: some View {
        Form{
            HStack{
                Text("Height")
                TextField("", text: $height)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .onReceive(Just(height)) { newValue in
                        let filtered = sanitize(newValue)
                        if filtered != newValue {
                            self.height = filtered
                        }
                        if metric {
                            h = parse(filtered) ?? 0
                            h = h/100
                        } else {
                            h = parse(filtered) ?? 0
                        }
                        defaults.set(filtered, forKey: "bmiHeight")
                        defaults.set(h, forKey: "bmiHeightD")

                    }
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }

                Text(metric ? NSLocalizedString("cm", comment: "BMI tool: unit for centimeters") : NSLocalizedString("in", comment: "BMI tool: unit abbreviation for inches, shown after the height and waist inputs"))


            }

            HStack{
                Text("Weight")
                TextField("", text: $weight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .onReceive(Just(weight)) { newValue in
                        let filtered = sanitize(newValue)
                        if filtered != newValue {
                            self.weight = filtered
                        }
                        w = parse(filtered) ?? 0
                        defaults.set(filtered, forKey: "bmiWeight")
                        defaults.set(w, forKey: "bmiWeightD")
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }


                Text(metric ? NSLocalizedString("kg", comment: "BMI tool: unit for kilograms") : NSLocalizedString("lb", comment: "BMI tool: unit for pounds"))
            }

            HStack{
                Text(NSLocalizedString("Waist", comment: "BMI tool: label of the waist circumference input"))
                TextField("", text: $waist)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .onReceive(Just(waist)) { newValue in
                        let filtered = sanitize(newValue)
                        if filtered != newValue {
                            self.waist = filtered
                        }
                        defaults.set(filtered, forKey: "bmiWaist")
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }

                Text(metric ? NSLocalizedString("cm", comment: "BMI tool: unit for centimeters") : NSLocalizedString("in", comment: "BMI tool: unit abbreviation for inches, shown after the height and waist inputs"))
            }

            Section{
                HStack {
                    Text("BMI")
                    Spacer()
                    Text(format(bmi))
                }
                HStack {
                    Text(NSLocalizedString("Waist-to-height ratio", comment: "BMI tool: label of the waist-to-height ratio result"))
                    Spacer()
                    Text(format(waistToHeight))
                }
            } footer: {
                Text(NSLocalizedString("BMI and waist-to-height ratio are only rough guides: they don't account for muscle mass, build, age or sex, and are no substitute for medical advice.", comment: "BMI tool: note below the results"))
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
            if(defaults.valueExists(forKey: "bmiWaist")){
                waist = defaults.string(forKey: "bmiWaist")!
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
