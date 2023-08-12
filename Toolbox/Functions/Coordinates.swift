//
//  Coordinates.swift
//  Toolbox
//
//  Created by Christian Nagel on 05.11.22.
//

import SwiftUI
import ToastSwiftUI
import Haptica
import CoreLocation

struct Coordinates: View {
    
    @State var isPresentingToast = false
    
    @StateObject var locationManager = Location_helper()
    
    var userLatitude: Double {
        return locationManager.lastLocation?.coordinate.latitude.rounded(toPlaces: 8) ?? 0
    }
    
    var userLongitude: Double {
        return locationManager.lastLocation?.coordinate.longitude.rounded(toPlaces: 8) ?? 0
    }
    
    var userAltitude: Double {
        return locationManager.lastLocation?.altitude.rounded(toPlaces: 2) ?? 0
    }
    
    var userCoordAccuracy: Double {
        return ((locationManager.lastLocation?.verticalAccuracy ?? 0 + (locationManager.lastLocation?.horizontalAccuracy ?? 0))/2).rounded(toPlaces: 2)
    }
    
    @AppStorage("coordsDisplay") var display: String = "decimal"
    
    var authStatus: String {
        locationManager.statusString
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
    
    func decimalToDMS(coordinate: Double, isLatitude: Bool) -> String {
        let absoluteCoordinate = abs(coordinate)
        
        let degrees = Int(absoluteCoordinate)
        let decimalMinutes = (absoluteCoordinate - Double(degrees)) * 60
        let minutes = Int(decimalMinutes)
        let seconds = (decimalMinutes - Double(minutes)) * 60
        
        let direction: String
        if isLatitude {
            direction = coordinate >= 0 ? "N" : "S"
        } else {
            direction = coordinate >= 0 ? "E" : "W"
        }
        
        
        return ("\(degrees)° \(minutes)' \(String(format: "%.2f", seconds))\" \(direction)")
    }
    
    var body: some View {
        Form {
            if(locationManager.locationStatus != .denied){
                Section{
                        Picker(selection: $display, label: Text("Display")) {
                            Text(NSLocalizedString("Decimal Degrees", comment: "GPS")).tag("decimal")
                            Text(NSLocalizedString("DMS", comment: "GPS")).tag("dms")
                        }
                    
                }
                
                Button(action: {
                    if(display == "decimal"){
                        UIPasteboard.general.string = String(userLatitude)
                    } else {
                        UIPasteboard.general.string = decimalToDMS(coordinate: userLatitude, isLatitude: true)
                    }
                    
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Latitude")
                        Spacer()
                        if(display == "decimal"){
                        Text(String(userLatitude))
                        } else {
                            Text(decimalToDMS(coordinate: userLatitude, isLatitude: true))
                        }
                    }
                }
                .tint(.primary)
                
                Button(action: {
                    if(display == "decimal"){
                        UIPasteboard.general.string = String(userLongitude)
                    } else {
                        UIPasteboard.general.string = decimalToDMS(coordinate: userLongitude, isLatitude:false)
                    }
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Longitude")
                        Spacer()
                        if(display == "decimal"){
                        Text(String(userLongitude))
                        } else {
                            Text(decimalToDMS(coordinate: userLongitude, isLatitude:false))
                        }
                    }
                }
                .tint(.primary)
                
                Button(action: {
                    UIPasteboard.general.string = decimalToDMS(coordinate: userLatitude, isLatitude: true) + ", " + decimalToDMS(coordinate: userLongitude, isLatitude: false)
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Coordinate String")
                        Spacer()
                        if (display == "decimal") {
                            Text(String(userLatitude) + ", " + String(userLongitude))
                        } else {
                            Text(decimalToDMS(coordinate: userLatitude, isLatitude: true) + ", " + decimalToDMS(coordinate: userLongitude, isLatitude: false))
                        }
                        
                    }
                }
                .tint(.primary)
                
                Button(action: {
                    UIPasteboard.general.string = String(userAltitude)
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Altitude")
                        Spacer()
                        Text(String(userAltitude) + " m")
                    }
                }
                .tint(.primary)
                
                Button(action: {
                    UIPasteboard.general.string = String(userCoordAccuracy)
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Accuracy")
                        Spacer()
                        Text(String(userCoordAccuracy) + " m")
                    }
                    
                }
                .tint(.primary)
            } else {
                VStack{
                    Text("You first have to allow Toolbox to access your location in order to see your coordinates.")
                    Button("Open Settings") {
                        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                        }
                    }
                }
            }
            
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Coordinates")
    }
}

struct Coordinates_Previews: PreviewProvider {
    static var previews: some View {
        Coordinates()
    }
}
