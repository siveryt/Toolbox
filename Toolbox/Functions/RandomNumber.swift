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
    /// What's typed into the fields; may be empty or incomplete while editing, `min` and `max` keep the last valid values.
    @State private var minText = ""
    @State private var maxText = ""
    @FocusState private var focusedField: Field?
    
    private enum Field { case min, max }
    
    func generateNumber() {
        // A closed range, so Int.max works as an upper bound
        result = String(Int.random(in: Swift.min(min, max)...Swift.max(min, max)))
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
        Form {
            HStack {
                Text("From")
                Spacer()
                TextField("1", text: $minText)
                    .focused($focusedField, equals: .min)
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
                TextField("1", text: $maxText)
                    .focused($focusedField, equals: .max)
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
        .onChange(of: minText) {
            if let value = Int(minText), value != min {
                min = value
                generateNumber()
            }
        }
        .onChange(of: maxText) {
            if let value = Int(maxText), value != max {
                max = value
                generateNumber()
            }
        }
        .onChange(of: focusedField) {
            // An empty or invalid field shows the value that's actually used again once editing ends
            if focusedField != .min { minText = String(min) }
            if focusedField != .max { maxText = String(max) }
        }
        .onAppear {
            minText = String(min)
            maxText = String(max)
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
