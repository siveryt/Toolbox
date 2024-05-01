//
//  PulsingFlashlight.swift
//  Toolbox
//
//  Created by Christian Nagel on 01.05.24.
//

import SwiftUI
import AVFoundation



struct PulsingFlashlight: View {
    @AppStorage("pulsingFlashlight_enabled") var enabled = false
    @State var active = true
    
    @AppStorage("pulsingFlashlight_speed") var speed = 9
    
    var speedProxy: Binding<Double>{
            Binding<Double>(get: {
                //returns the score as a Double
                return Double(speed)
            }, set: {
                speed = Int($0)
            })
        }
    
    @State var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let speeds = [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1,2,3,4,5,6,7,8,9,10]
    
    var body: some View {
        
        Form {
            Toggle(isOn: $enabled){
                Text("Enabled")
            }
            .onChange(of: enabled) {
                if (!enabled) {
                    setFlash(on: false)
                }
            }
            
            Stepper(value: $speed,
                    in: 0...speeds.count-1,
                    step: 1) {
                Text("Speed")
            }
                    .onChange(of: speed){
                        timer = Timer.publish(every: 1/speeds[speed], on: .main, in: .common).autoconnect()
                    }
            Slider(value: speedProxy, in: 0...Double(speeds.count-1), step: 1)
            
        }
        
        .onDisappear {
            timer.upstream.connect().cancel()
            setFlash(on: false)
        }
        .onReceive(timer) { input in
            setFlash(on: (!active && enabled))
            active.toggle()
        }
        .onAppear() {
            timer = Timer.publish(every: 1/speeds[speed], on: .main, in: .common).autoconnect()
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Pulsing Flashlight")
        
    }
    
    func setFlash(on: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if (on) {
                do {
                    try device.setTorchModeOn(level: 1.0)
                } catch {
                    print(error)
                }
            } else {
                device.torchMode = AVCaptureDevice.TorchMode.off
            }

            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
}

#Preview {
    PulsingFlashlight()
}
