//
//  Speed.swift
//  Toolbox
//
//  Created by Christian Nagel on 05.11.22.
//

import SwiftUI
import LocationProvider
import ToastSwiftUI
import Haptica

struct Speed: View {
    
    @State var isPresentingToast = false
    
    @StateObject var locationManager = Location_helper()
    
    var userSpeed: Double {
        var speed = (locationManager.lastLocation?.speed ?? 0) * 3.6
        if (speed < 0) {speed = 0}
        return speed.rounded(toPlaces: 2)
    }
    var userSpeedAccuracy: Double {
        var accuracy = (locationManager.lastLocation?.speedAccuracy ?? 0) * 3.6
        if (accuracy < 0) {accuracy = 0}
        return accuracy.rounded(toPlaces: 2)
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
                    UIPasteboard.general.string = String(userSpeed)
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Speed")
                        Spacer()
                        Text(String(userSpeed) + " km/h")
                    }
                }
                .tint(.primary)
                
                Button(action: {
                    UIPasteboard.general.string = String(userSpeedAccuracy)
                    Haptic.impact(.light).generate()
                    presentToast()
                }){
                    HStack {
                        Text("Speed Accuracy")
                        Spacer()
                        Text(String(userSpeedAccuracy) + " km/h")
                    }
                }
                .tint(.primary)
                
            } else {
                VStack{
                    Text("You first have to allow Toolbox to access your location in order to see your speed.")
                    Button("Open Settings") {
                        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Speed")
    }
}

struct Speed_Previews: PreviewProvider {
    static var previews: some View {
        Speed()
    }
}
