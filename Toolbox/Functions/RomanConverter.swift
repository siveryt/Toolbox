import SwiftUI
import RomanNumeralKit

struct RomanConverter: View {
    @State var arabic = ""
    @State var roman = ""
    @State var alert:Bool = false
    var body: some View {
        let arabicBinding = Binding<String>(get: {
            self.arabic
        }, set: {
            
            
            self.arabic = $0
            
            do {
                if($0 != ""){
                    if(Int(arabic)! > 3999){
                        alert = true
                    }else{
                        self.roman = try String(RomanNumeral(from: Int(arabic)!).stringValue)
                    }
                }else{
                    self.roman = ""
                }
            }catch{
                self.roman = ""
                
            }
        })
        let romanBinding = Binding<String>(get: {
            self.roman
        }, set: {
            self.roman = $0.uppercased()
            do {
                if($0 != ""){
                    if(try RomanNumeral(from:$0).intValue > 3999){
                        alert = true
                    }else{
                        self.arabic = try String(RomanNumeral(from: roman).intValue)
                    }

                }else{
                    self.arabic = ""
                }
            }catch{
                self.arabic = ""
            }
        })
        
        Form{
            HStack {
                Text("Roman")
                TextField("MMXXII", text: romanBinding)
                    .disableAutocorrection(true)
                    .textCase(/*@START_MENU_TOKEN@*/.uppercase/*@END_MENU_TOKEN@*/)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Arabic")
                TextField("2022", text: arabicBinding)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        .alert(isPresented: $alert) {
            Alert(
                title: Text("Number to big!"),
                message: Text("You can't convert numbers bigger than 3999.")
            )
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
