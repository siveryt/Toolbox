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
        return String(formattedSpeed.split(separator: " ")[0])
    }
    
    var userSpeedUnit: String {
        let formatter = MeasurementFormatter()
        let locale = Locale.current
        formatter.locale = locale
        let speedExample = Measurement(value: max(locationManager.lastLocation?.speed ?? 0, 0), unit: UnitSpeed.metersPerSecond)

        let formattedSpeed = formatter.string(from: speedExample)
        return String(formattedSpeed.split(separator: " ")[1])
    }
    
    var userSpeedAccuracy: String {
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
        VStack{
            
        
            if(locationManager.locationStatus != .denied){
                GeometryReader { geometry in
                    VStack{
                        Spacer()
                        VStack {
                            
                            Text(userSpeed)
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.8, design: .default)).monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.01)
                                .padding() // Adds default padding
                                .frame(maxWidth: .infinity)
                            
                            Text(userSpeedUnit)
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.1, design: .default))
                        }
                        Spacer()
                        
                        Text("±" + userSpeedAccuracy)
                            .foregroundStyle(.secondary)
                    }
                }
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
