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
    
    /// The current fix, or nil while there is none yet (no permission, still searching).
    var location: CLLocation? {
        locationManager.lastLocation
    }
    
    var userLatitude: Double? {
        location?.coordinate.latitude
    }
    
    var userLongitude: Double? {
        location?.coordinate.longitude
    }
    
    /// Altitude, only when Core Location reports it as valid (verticalAccuracy >= 0).
    var userAltitude: Double? {
        guard let location, location.verticalAccuracy >= 0 else { return nil }
        return location.altitude
    }
    
    /// Horizontal accuracy in meters, nil when invalid (negative).
    var userCoordAccuracy: Double? {
        guard let location, location.horizontalAccuracy >= 0 else { return nil }
        return location.horizontalAccuracy
    }
    
    /// Location access was refused by the user or is not possible on this device.
    var isAccessDenied: Bool {
        locationManager.locationStatus == .denied || locationManager.locationStatus == .restricted
    }
    
    @AppStorage("coordsDisplay") var display: String = "decimal"
    
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
        // Round to hundredths of a second first, so 59.999" carries over to the next minute instead of showing 60.00"
        let totalHundredths = Int((abs(coordinate) * 360_000).rounded())
        
        let degrees = totalHundredths / 360_000
        let minutes = (totalHundredths % 360_000) / 6_000
        let seconds = Double(totalHundredths % 6_000) / 100
        
        let direction: String
        if isLatitude {
            direction = coordinate >= 0 ? "N" : "S"
        } else {
            direction = coordinate >= 0 ? "E" : "W"
        }
        
        return "\(degrees)° \(minutes)' \(String(format: "%.2f", seconds))\" \(direction)"
    }
    
    /// Decimal degrees for display, with the current locale's decimal separator.
    func decimalDisplay(_ coordinate: Double) -> String {
        coordinate.formatted(.number.precision(.fractionLength(6)).grouping(.never))
    }
    
    /// Decimal degrees for copying, always with "." so maps and other apps understand it.
    func decimalCopy(_ coordinate: Double) -> String {
        String(format: "%.6f", coordinate)
    }
    
    /// The combined row: Maidenhead locator or both coordinates, nil while there is no fix.
    var coordinateString: String? {
        guard let latitude = userLatitude, let longitude = userLongitude else { return nil }
        switch display {
        case "maidenhead":
            return decimalToMaidenhead(latitude: latitude, longitude: longitude)
        case "decimal":
            return decimalCopy(latitude) + ", " + decimalCopy(longitude)
        default:
            return decimalToDMS(coordinate: latitude, isLatitude: true) + ", " + decimalToDMS(coordinate: longitude, isLatitude: false)
        }
    }
    
    func meters(_ value: Double) -> String {
        Measurement(value: value, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
    }
    
    func decimalToMaidenhead(latitude: Double, longitude: Double) -> String {
        // Keep the poles and the antimeridian inside the grid (90° N would otherwise index past "X")
        var lat = min(max(latitude + 90.0, 0), 179.999_999)
        var lon = min(max(longitude + 180.0, 0), 359.999_999)
        var maidenhead = ""
        
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWX"
        let subsquareLetters = "abcdefghijklmnopqrstuvwx"
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
        
        // Subsquare: 5 minutes longitude × 2.5 minutes latitude, written in lowercase ("JO62qm")
        let lonSubIndex = min(Int(lon / 5), 23)
        let latSubIndex = min(Int(lat / 2.5), 23)
        maidenhead.append(subsquareLetters[subsquareLetters.index(subsquareLetters.startIndex, offsetBy: lonSubIndex)])
        maidenhead.append(subsquareLetters[subsquareLetters.index(subsquareLetters.startIndex, offsetBy: latSubIndex)])
        
        return maidenhead
    }
    
    var body: some View {
        Group {
            if !isAccessDenied {
                Form {
                Section{
                        Picker(selection: $display, label: Text("Display")) {
                            Text(NSLocalizedString("Decimal Degrees", comment: "Coordinates tool: format picker option, coordinates as decimal degrees (52.520008)")).tag("decimal")
                            Text(NSLocalizedString("DMS", comment: "Coordinates tool: format picker option, coordinates as degrees, minutes and seconds (52° 31' 12.03\" N)")).tag("dms")
                            Text(NSLocalizedString("Maidenhead", comment: "Coordinates tool: Maidenhead grid locator, a ham radio location code")).tag("maidenhead")
                        }
                    
                }
                if display != "maidenhead" {
                    CoordinateValueRow(
                        content: userLatitude.map { display == "decimal" ? decimalDisplay($0) : decimalToDMS(coordinate: $0, isLatitude: true) },
                        copyText: userLatitude.map { display == "decimal" ? decimalCopy($0) : decimalToDMS(coordinate: $0, isLatitude: true) },
                        propertyName: NSLocalizedString("Latitude", comment: "Coordinates tool: row label"))
                        .environment(\.copyToast, $isPresentingToast)
                    CoordinateValueRow(
                        content: userLongitude.map { display == "decimal" ? decimalDisplay($0) : decimalToDMS(coordinate: $0, isLatitude: false) },
                        copyText: userLongitude.map { display == "decimal" ? decimalCopy($0) : decimalToDMS(coordinate: $0, isLatitude: false) },
                        propertyName: NSLocalizedString("Longitude", comment: "Coordinates tool: row label"))
                        .environment(\.copyToast, $isPresentingToast)
                }
                CoordinateValueRow(content: coordinateString, copyText: coordinateString, propertyName: display == "maidenhead" ? NSLocalizedString("Maidenhead", comment: "Coordinates tool: row label for the Maidenhead grid locator, a ham radio location code") : NSLocalizedString("Coordinate String", comment: "Coordinates tool: row label for latitude and longitude combined into one copyable text"))
                    .environment(\.copyToast, $isPresentingToast)
                CoordinateValueRow(content: userAltitude.map(meters), copyText: userAltitude.map(meters), propertyName: NSLocalizedString("Altitude", comment: "Coordinates tool: row label"))
                    .environment(\.copyToast, $isPresentingToast)
                CoordinateValueRow(content: userCoordAccuracy.map { "± " + meters($0) }, copyText: userCoordAccuracy.map(meters), propertyName: NSLocalizedString("Accuracy", comment: "Coordinates tool: row label, accuracy of the position in meters"))
                    .environment(\.copyToast, $isPresentingToast)
                }
            } else {
                PermissionDeniedView(
                    title: NSLocalizedString("Location Access Required", comment: "A message displayed when the user hasn't granted location access to the app."),
                    systemImage: "location.slash",
                    description: NSLocalizedString("You first have to allow Toolbox to access your location to see your coordinates.", comment: "Coordinates tool: shown without location access")
                )
            }
            }
        
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Coordinates")
    }
}

/// Like KeyValueProperty, but shows "–" and can't be copied while there is no value,
/// and can copy a different text than it shows (e.g. "." instead of the locale's decimal separator).
private struct CoordinateValueRow: View {
    
    var content: String?
    var copyText: String?
    var propertyName: String
    @Environment(\.copyToast) var copyToast
    
    var body: some View {
        if let copyText, content != nil {
            Button(action: {
                withAnimation {
                    copyToast?.wrappedValue = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        copyToast?.wrappedValue = false
                    }
                }
                UIPasteboard.general.string = copyText
            }, label: {
                label
            }).tint(.primary)
        } else {
            label
        }
    }
    
    var label: some View {
        VStack {
            HStack {
                Text(propertyName)
                    .font(.callout)
                    .dynamicTypeSize(.small)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                Spacer()
            }
            HStack {
                Text(content ?? "–")
                    .foregroundColor(content == nil ? .secondary : .primary)
                Spacer()
            }
        }
    }
}

struct Coordinates_Previews: PreviewProvider {
    static var previews: some View {
        Coordinates()
    }
}
