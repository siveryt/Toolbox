//
//  ColorPicker.swift
//  Toolbox
//
//  Created by Christian Nagel on 10.04.22.
//

import SwiftUI
import Haptica
import ToastSwiftUI

struct ColorPickerView: View {
    let defaults = UserDefaults.standard
    @State var color: Color = Color(red: 0, green: 0, blue: 0, opacity: 1)
    @State private var drawSwiftUIColor: Color = Color.red
    @State private var drawOpacity: Double = 1.0
    @State private var drawUIColor: UIColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
    @State private var drawHexNumber: String = "#FF0000"
    
    
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
    @State var isPresentingToast = false
    
    var body: some View {
        Form{
            ColorPicker(NSLocalizedString("Choose Color", comment: "Color Picker tool: label of the color well"), selection: $drawSwiftUIColor, supportsOpacity: true)
                .onChange(of: drawSwiftUIColor) {
                    getColorsFromPicker(pickerColor: drawSwiftUIColor)
                    saveColor()
                }
            
            RoundedRectangle(cornerSize: CGSize(width: 5, height: 5))
                .fill(drawSwiftUIColor)
            Section(NSLocalizedString("Colorcodes", comment: "Color Picker tool: section header for HEX/RGB codes")){
                Button(action: {
                    UIPasteboard.general.string = drawHexNumber
                    Haptic.impact(.light).generate()
                    presentToast() 
                }){
                    HStack {
                    Text(NSLocalizedString("HEX", comment: "Color Picker tool: label for the hexadecimal color code"))
                    Spacer()
                    Text(drawHexNumber)
                        
                    }
                }.tint(.primary)
                    
                
                Button(action:{
                    UIPasteboard.general.string = rgbToString(input: drawUIColor)
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                    Text(NSLocalizedString("RGB", comment: "Color Picker tool: label for the color code as red, green, blue values (0–255)"))
                    Spacer()
                    Text(rgbToString(input: drawUIColor))
                    }
                }.tint(.primary)
                
                Button(action:{
                    UIPasteboard.general.string = rgbaToString(input: drawUIColor)
                    Haptic.impact(.light).generate()
                    
                    presentToast()
                    
                }){
                    HStack {
                    Text(NSLocalizedString("RGBA", comment: "Color Picker tool: label for the color code as red, green, blue (0–255) and opacity (0–1) values"))
                    Spacer()
                    Text(rgbaToString(input: drawUIColor))
                    }
                }
                .tint(.primary)

            }
            
            
            
            // SquareColorPickerView(colorValue: $color)
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .onAppear(){
            // Restore first, then apply it to the picker and the codes
            restoreColor()
            resetColorPickerWithUIColor()
            getColorsFromPicker(pickerColor: drawSwiftUIColor)
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle(NSLocalizedString("Color Picker", comment: "Menu item"))
    }
        
    
    /// Loads the last picked color (including its opacity); ignores missing or unreadable data.
    func restoreColor() {
        guard let userSelectedColorData = UserDefaults.standard.data(forKey: "UserSelectedColor"),
              let userSelectedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: userSelectedColorData) else { return }
        drawUIColor = userSelectedColor
        drawOpacity = Double(userSelectedColor.rgba.alpha)
    }
    
    /// Saves the picked color; UIColor keeps its alpha, so the opacity is saved too.
    func saveColor() {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: drawUIColor, requiringSecureCoding: true) else { return }
        UserDefaults.standard.set(data, forKey: "UserSelectedColor")
    }
    
    func getColorsFromPicker(pickerColor: Color) {
        let components = UIColor(pickerColor).rgba
        
        // Extended-range colors can fall outside 0...1
        let r = min(max(components.red, 0), 1)
        let g = min(max(components.green, 0), 1)
        let b = min(max(components.blue, 0), 1)
        let alpha = min(max(components.alpha, 0), 1)
        
        // Update UIColor
        drawUIColor = UIColor(red: r, green: g, blue: b, alpha: alpha)
        // Update Opacity
        drawOpacity = Double(alpha)
        
        // Update hex
        let rgb: Int = to255(r) << 16 | to255(g) << 8 | to255(b) << 0
        drawHexNumber = String(format: "#%06X", rgb)
    }
    
    /// 0...1 component to 0...255, rounded instead of truncated.
    func to255(_ component: CGFloat) -> Int {
        Int((min(max(component, 0), 1) * 255).rounded())
    }
    
    func resetColorPickerWithUIColor() {
        let color: UIColor = drawUIColor
        let r: Double = Double(color.rgba.red)
        let g: Double = Double(color.rgba.green)
        let b: Double = Double(color.rgba.blue)
        drawSwiftUIColor = Color(red: r, green: g, blue: b, opacity: drawOpacity)
    }
    /// "255, 0, 0, 0.5": a color code like CSS rgba(), so the opacity always uses "." (a decimal comma would clash with the separators).
    func rgbaToString(input: UIColor) -> String {
        let alpha = Double(min(max(input.rgba.alpha, 0), 1))
        return rgbToString(input: input) + ", " + alpha.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
    func rgbToString(input: UIColor) -> String {
        let rgba = input.rgba
        return "\(to255(rgba.red)), \(to255(rgba.green)), \(to255(rgba.blue))"
    }
    
}

struct ColorPicker_Previews: PreviewProvider {
    static var previews: some View {
        ColorPickerView()
    }
}


extension UIColor {
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
    
}
