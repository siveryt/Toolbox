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
    
    func decimalToMaidenhead(latitude: Double, longitude: Double) -> String {
        var lat = latitude + 90.0
        var lon = longitude + 180.0
        var maidenhead = ""
        
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWX"
        let numbers = "0123456789"
        
        // Field: 20° longitude × 10° latitude
        let lonFieldIndex = Int(lon / 20)
        let latFieldIndex = Int(lat / 10)
        maidenhead.append(letters[letters.index(letters.startIndex, offsetBy: lonFieldIndex)])
        maidenhead.append(letters[letters.index(letters.startIndex, offsetBy: latFieldIndex)])
        
        lon = fmod(lon, 20)
        lat = fmod(lat, 10)
        
        // Square: 2° longitude × 1° latitude
        let lonSquareIndex = Int(lon / 2)
        let latSquareIndex = Int(lat / 1)
        maidenhead.append(numbers[numbers.index(numbers.startIndex, offsetBy: lonSquareIndex)])
        maidenhead.append(numbers[numbers.index(numbers.startIndex, offsetBy: latSquareIndex)])
        
        lon = fmod(lon, 2) * 60
        lat = fmod(lat, 1) * 60
        
        // Subsquare: 5 minutes longitude × 2.5 minutes latitude
        let lonSubIndex = Int(lon / 5)
        let latSubIndex = Int(lat / 2.5)
        maidenhead.append(letters[letters.index(letters.startIndex, offsetBy: lonSubIndex)])
        maidenhead.append(letters[letters.index(letters.startIndex, offsetBy: latSubIndex)])
        
        return maidenhead
    }
    
    var body: some View {
        Group {
            if(locationManager.locationStatus != .denied){
                Form {
                Section{
                        Picker(selection: $display, label: Text("Display")) {
                            Text(NSLocalizedString("Decimal Degrees", comment: "GPS")).tag("decimal")
                            Text(NSLocalizedString("DMS", comment: "GPS")).tag("dms")
                            Text(NSLocalizedString("Maidenhead", comment: "GPS")).tag("maidenhead")
                        }
                    
                }
                if display != "maidenhead" {
                    KeyValueProperty(content: display == "decimal" ? String(userLatitude) : decimalToDMS(coordinate: userLatitude, isLatitude: true), propertyName: NSLocalizedString("Latitude", comment: ""))
                        .environment(\.copyToast, $isPresentingToast)
                    KeyValueProperty(content: display == "decimal" ? String(userLongitude) : decimalToDMS(coordinate: userLongitude, isLatitude: false), propertyName: NSLocalizedString("Longitude", comment: ""))
                        .environment(\.copyToast, $isPresentingToast)
                }
                KeyValueProperty(content: display == "maidenhead" ? decimalToMaidenhead(latitude: userLatitude, longitude: userLongitude) : (display == "decimal" ? String(userLatitude) + ", " + String(userLongitude) : decimalToDMS(coordinate: userLatitude, isLatitude: true) + ", " + decimalToDMS(coordinate: userLongitude, isLatitude: false)), propertyName: display == "maidenhead" ? NSLocalizedString("Maidenhead", comment: "") : NSLocalizedString("Coordinate String", comment: ""))
                    .environment(\.copyToast, $isPresentingToast)
                KeyValueProperty(content: String(userAltitude) + " m", propertyName: NSLocalizedString("Altitude", comment: ""))
                    .environment(\.copyToast, $isPresentingToast)
                KeyValueProperty(content: String(abs(userCoordAccuracy)) + " m", propertyName: NSLocalizedString("Accuracy", comment: ""))
                    .environment(\.copyToast, $isPresentingToast)
                }
            } else {
                VStack{
                    Text("You first have to allow Toolbox to access your location to see your coordinates.")
                        .multilineTextAlignment(.center)
                        .padding()
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
