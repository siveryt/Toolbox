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
            ColorPicker("Choose color", selection: $drawSwiftUIColor, supportsOpacity: true)
                .onChange(of: drawSwiftUIColor) { newValue in
                    getColorsFromPicker(pickerColor: newValue)
                    guard let data : Data = try? NSKeyedArchiver.archivedData(withRootObject: drawUIColor, requiringSecureCoding: false) as Data else { return }
                    UserDefaults.standard.set(data, forKey: "UserSelectedColor")
                    UserDefaults.standard.synchronize()
                }
                .onAppear(){
                    resetColorPickerWithUIColor()
                }
            
            RoundedRectangle(cornerSize: CGSize(width: 5, height: 5))
                .fill(drawSwiftUIColor)
            Section("Colorcodes"){
                Button(action: {
                    UIPasteboard.general.string = drawHexNumber
                    Haptic.impact(.light).generate()
                    presentToast() 
                }){
                    HStack {
                    Text("HEX")
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
                    Text("RGB")
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
                    Text("RGBA")
                    Spacer()
                    Text(rgbaToString(input: drawUIColor))
                    }
                }
                .tint(.primary)

            }
            
            
            
            // SquareColorPickerView(colorValue: $color)
        }
        .toast(isPresenting: $isPresentingToast, message: "Copied", icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .onAppear(){
            if let userSelectedColorData = UserDefaults.standard.object(forKey: "UserSelectedColor") as? Data {
                
                do {
                    guard let userSelectedColor = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(userSelectedColorData) as? UIColor else {
                        fatalError("loadWidgetDataArray - Can't get Array")
                    }
                    drawUIColor = userSelectedColor
                } catch {
                    fatalError("loadWidgetDataArray - Can't encode data: \(error)")
                }
                
    
            }
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Color Picker")
    }
        
    
    
    func getColorsFromPicker(pickerColor: Color) {
        let colorString = "\(pickerColor)"
        let colorArray: [String] = colorString.components(separatedBy: " ")
        
        if colorArray.count > 1 {
            var r: CGFloat = CGFloat((Float(colorArray[1]) ?? 1))
            var g: CGFloat = CGFloat((Float(colorArray[2]) ?? 1))
            var b: CGFloat = CGFloat((Float(colorArray[3]) ?? 1))
            let alpha: CGFloat = CGFloat((Float(colorArray[4]) ?? 1))
            
            if (r < 0.0) {r = 0.0}
            if (g < 0.0) {g = 0.0}
            if (b < 0.0) {b = 0.0}
            
            if (r > 1.0) {r = 1.0}
            if (g > 1.0) {g = 1.0}
            if (b > 1.0) {b = 1.0}
            
            // Update UIColor
            drawUIColor = UIColor(red: r, green: g, blue: b, alpha: alpha)
            // Update Opacity
            drawOpacity = Double(alpha)
            
            // Update hex
            let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
            drawHexNumber = String(format: "#%06X", rgb)
        }
        
    }
    
    
    func resetColorPickerWithUIColor() {
        let color: UIColor = drawUIColor
        let r: Double = Double(color.rgba.red)
        let g: Double = Double(color.rgba.green)
        let b: Double = Double(color.rgba.blue)
        drawSwiftUIColor = Color(red: r, green: g, blue: b, opacity: drawOpacity)
    }
    func rgbaToString(input: UIColor) -> String {
        var result = ""
        result += String(Int(Double(input.rgba.red)*255))
        result += ", "
        result += String(Int(Double(input.rgba.green)*255))
        result += ", "
        result += String(Int(Double(input.rgba.blue)*255))
        result += ", "
        result += String(Double(input.rgba.alpha))
        
        return result
    }
    func rgbToString(input: UIColor) -> String {
        var result = ""
        result += String(Int(Double(input.rgba.red)*255))
        result += ", "
        result += String(Int(Double(input.rgba.green)*255))
        result += ", "
        result += String(Int(Double(input.rgba.blue)*255))
        
        return result
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
