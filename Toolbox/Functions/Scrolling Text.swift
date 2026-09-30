//
//  Scrolling Text.swift
//  Toolbox
//
//  Created by Christian Nagel on 19.05.24.
//

import SwiftUI
import MarqueeText
import TipKit

/// Hint shown in the scrolling-text full-screen mode explaining how to exit it.
struct ScrollingTextFullscreenTip: Tip {
    var title: Text {
        Text("Exit Fullscreen")
    }
    var message: Text? {
        Text("Tap anywhere to minimize")
    }
    var image: Image? {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
    }
}

struct Scrolling_Text: View {
    private let fullscreenTip = ScrollingTextFullscreenTip()
    @State var enabled = false
    @State var scrollerActive = false
    @State var rotateAlert = false
    @AppStorage("Scrolling Text-speed") var scrollingSpeed = 1.0
    @AppStorage("Scrolling Text-text") var text = ""
    
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
                Button("Start Scrolling"){
                    if(enabled) {
                        scrollerActive = true
                    } else {
                        rotateAlert = true
                    }
                }
                .tint(enabled ? .accentColor : .secondary)
            }
            
        }
        // Use the available space instead of the device orientation, so this also works on unusual display shapes (e.g. iPhone Duo)
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height
        } action: { isWide in
            enabled = isWide
            scrollerActive = isWide ? scrollerActive : false
        }
        .alert("Info", isPresented: $rotateAlert) {
        } message: {
            Text("You need to rotate your device to enable the scrolling text.")
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
                        .ignoresSafeArea()
                    }
                    .avoidingActiveDivision()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        scrollerActive = false
                        fullscreenTip.invalidate(reason: .actionPerformed)
                    }
                    .overlay(alignment: .top) {
                        TipView(fullscreenTip)
                            .padding()
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
