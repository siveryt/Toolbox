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
    
    var body: some View {
        Form {
            if(locationManager.locationStatus != .denied){
                Button(action: {
                    UIPasteboard.general.string = String(userLatitude)
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Latitude")
                        Spacer()
                        Text(String(userLatitude))
                    }
                }
                .tint(.primary)
                
                Button(action: {
                    UIPasteboard.general.string = String(userLongitude)
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Longitude")
                        Spacer()
                        Text(String(userLongitude))
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
