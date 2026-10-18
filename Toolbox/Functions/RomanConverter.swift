import SwiftUI
import RomanNumeralKit

struct RomanConverter: View {
    @AppStorage("romanArabic") var arabic = ""
    @AppStorage("romanRoman") var roman = ""
    @State var alert:Bool = false
    @FocusState private var focusedField: Field?
    
    private enum Field { case roman, arabic }
    
    var body: some View {
        // The fields bind straight to the stored strings and get cleaned up in onChange: a binding that just
        // ignores invalid input leaves that input visible in the field.
        Form{
            HStack {
                Text("Roman")
                TextField("MMXXII", text: $roman)
                    .focused($focusedField, equals: .roman)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.characters)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Arabic")
                TextField("2022", text: $arabic)
                    .focused($focusedField, equals: .arabic)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        .onChange(of: roman) { _, newValue in
            let cleaned = String(newValue.uppercased().filter { "IVXLCDM".contains($0) })
            guard cleaned == newValue else {
                roman = cleaned
                return
            }
            // Only the field being edited updates the other one, so converting doesn't rewrite what was typed
            guard focusedField == .roman else { return }
            guard !cleaned.isEmpty else {
                arabic = ""
                return
            }
            do {
                arabic = String(try RomanNumeral(from: cleaned).intValue)
            } catch RomanNumeralError.valueGreaterThanMaximum {
                arabic = ""
                alert = true
            } catch {
                arabic = ""
            }
        }
        .onChange(of: arabic) { _, newValue in
            // Digits only, and few enough that they always fit into an Int
            let cleaned = String(newValue.filter { ("0"..."9").contains($0) }.prefix(6))
            guard cleaned == newValue else {
                arabic = cleaned
                return
            }
            guard focusedField == .arabic else { return }
            guard let value = Int(cleaned) else {
                roman = ""
                return
            }
            if value > 3999 {
                // Don't leave the old Roman numeral next to a number it doesn't match
                roman = ""
                alert = true
                return
            }
            roman = (try? RomanNumeral(from: value)).map { String($0.stringValue) } ?? ""
        }
        .alert("Number too big", isPresented: $alert) {
        } message: {
            Text("You can't convert numbers bigger than 3999.")
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Roman Numbers")
    
    }

}

struct RomanConverter_Previews: PreviewProvider {
    static var previews: some View {
        RomanConverter()
    }
}
