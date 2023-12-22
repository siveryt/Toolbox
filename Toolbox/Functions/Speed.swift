//
//  Speed.swift
//  Toolbox
//
//  Created by Christian Nagel on 05.11.22.
//

import SwiftUI
import ToastSwiftUI
import Haptica

struct Speed: View {
    
    @State var isPresentingToast = false
    
    @StateObject var locationManager = Location_helper()
    
    var userSpeed: String {
        
        let formatter = MeasurementFormatter()
        let locale = Locale.current
        formatter.locale = locale
        let speedExample = Measurement(value: max(locationManager.lastLocation?.speed ?? 0, 0), unit: UnitSpeed.metersPerSecond)

        let formattedSpeed = formatter.string(from: speedExample)
        return formattedSpeed
    }
    var userSpeedAccuracy: Double {
        let formatter = MeasurementFormatter()
        let locale = Locale.current
        formatter.locale = locale
        let speedExample = Measurement(value: max(locationManager.lastLocation?.speedAccuracy ?? 0, 0), unit: UnitSpeed.metersPerSecond)

        let formattedSpeed = formatter.string(from: speedExample)
        return formattedSpeed
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
                        Text(userSpeed)
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
