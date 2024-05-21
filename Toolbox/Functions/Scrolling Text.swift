//
//  Scrolling Text.swift
//  Toolbox
//
//  Created by Christian Nagel on 19.05.24.
//

import SwiftUI
import MarqueeText
import Combine

struct Scrolling_Text: View {
    @State var scrollerActive = false
    @State var rotateAlert = false
    @AppStorage("Scrolling Text-speed") var scrollingSpeed = 1.0
    @AppStorage("Scrolling Text-text") var text = ""
    
    @State var orientation = UIDevice.current.orientation

        let orientationChanged = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .makeConnectable()
            .autoconnect()
    
    var body: some View {
        
        Form {
            TextField("Scrolling Text", text: $text)
                .onReceive(NotificationCenter.default.publisher(
                    for: UITextField.textDidBeginEditingNotification)) { _ in
                        DispatchQueue.main.async {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                            )
                        }
                    }
            
            Slider(value: $scrollingSpeed, in: 0.1...2.0, step: 0.1)
            
            Section {
                Button("Start scrolling"){
                    if(orientation.isLandscape) {
                        scrollerActive = true
                    } else {
                        rotateAlert = true
                    }
                }
                .tint(orientation.isLandscape ? .accentColor : .secondary)
            }
            
        }
        .onReceive(orientationChanged) { _ in
            self.orientation = UIDevice.current.orientation
            if (!orientation.isLandscape) {
                scrollerActive = false
            }
        }
        .alert(isPresented: $rotateAlert) {
            Alert(title: Text("Info"),
                  message: Text("You need to rotate your device to show the scrolling text.")
            )
        }
        
        .fullScreenCover(isPresented: $scrollerActive) {
                    GeometryReader { geometry in
                        MarqueeText(
                            text: text,
                            font: UIFont.systemFont(ofSize: geometry.size.height),
                            leftFade: 0,
                            rightFade: 0,
                            startDelay: 0,
                            duration: Double(text.count)/(2.0 * scrollingSpeed)
                        )
                        .gesture(MagnifyGesture()
                            .onEnded { value in
                                scrollerActive = false
                            }
                        )
                        .ignoresSafeArea()
                    }
        }
        
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Scrolling Text")
    }
}

public struct SelectTextOnEditingModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                if let textField = obj.object as? UITextField {
                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                }
            }
    }
}

extension View {

    /// Select all the text in a TextField when starting to edit.
    /// This will not work with multiple TextField's in a single view due to not able to match the selected TextField with underlying UITextField
    public func selectAllTextOnEditing() -> some View {
        modifier(SelectTextOnEditingModifier())
    }
}




#Preview {
    Scrolling_Text()
}
