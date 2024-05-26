//
//  RandomNumber.swift
//  Toolbox
//
//  Created by Christian Nagel on 20.03.22.
//

import SwiftUI
import Haptica
import Combine
import ToastSwiftUI

extension String {
    var isInt: Bool {
        return Int(self) != nil
    }
}

struct RandomNumber: View {
    
    @AppStorage("rannumMin", store: .standard) var min: Int = 1
    @AppStorage("rannumMax", store: .standard) var max: Int = 100
    @AppStorage("rannumResult", store: .standard) var result: String = ""
    @State var isPresentingToast: Bool = false
    
    func generateNumber() {
        if(min < max){
            result = String(Int.random(in: min ..< max+1))
        }else if (min > max){
            result = String(Int.random(in: max ..< min+1))
        }else {
            result = String(min)
        }
    }
    
    func presentToast() {
        withAnimation {
            isPresentingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isPresentingToast = false
            }
        }
    }
    
    var body: some View {
        
        
        
        let minBinding = Binding<String>(get: {
            String(self.min)
        }, set: {
            if ($0.isInt) {
                self.min = Int($0 == "" ? "0" : $0)!
            }
            generateNumber()
            
        })
        let maxBinding = Binding<String>(get: {
            String(self.max)
        }, set: {
            if ($0.isInt) {
                self.max = Int($0 == "" ? "0" : $0)!
            }
            generateNumber()
        })
        
        Form {
            HStack {
                Text("From")
                Spacer()
                TextField("1", text: minBinding)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }
            }
            
            HStack {
                Text("To")
                Spacer()
                TextField("1", text: maxBinding)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }
            }
            Section {
                Button(action: {
                    UIPasteboard.general.string = result
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Result")
                        Spacer()
                        Text(result)
                        
                    }
                }
                .tint(.primary)
            }
            Section {
                
                Button("New Number"){
                    Haptic.impact(.light).generate()
                    generateNumber()
                    
                }
            }
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Random Number")
    }
}

struct RandomNumber_Previews: PreviewProvider {
    static var previews: some View {
        RandomNumber()
    }
}
