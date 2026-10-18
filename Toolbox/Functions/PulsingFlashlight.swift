//
//  PulsingFlashlight.swift
//  Toolbox
//
//  Created by Christian Nagel on 01.05.24.
//

import SwiftUI
import AVFoundation
import Combine



struct PulsingFlashlight: View {
    /// Not persisted, so opening the tool never starts strobing by itself.
    @State var enabled = false
    @State var active = true
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("pulsingFlashlight_speed") var speed = 9
    
    var speedProxy: Binding<Double>{
            Binding<Double>(get: {
                //returns the score as a Double
                return Double(speed)
            }, set: {
                speed = Int($0)
            })
        }
    
    @State var timer = Timer.publish(every: 1, on: .main, in: .common)
    /// The running timer; cancelling it stops the timer.
    @State private var timerConnection: Cancellable?
    
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
                        restartTimer()
                    }
            Slider(value: speedProxy, in: 0...Double(speeds.count-1), step: 1)
            
        }
        
        .onDisappear {
            enabled = false
            stopTimer()
            setFlash(on: false)
        }
        .onReceive(timer) { input in
            setFlash(on: (!active && enabled))
            active.toggle()
        }
        .onAppear() {
            restartTimer()
        }
        // Don't keep the torch strobing in the background or behind Control Center.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                restartTimer()
            } else {
                enabled = false
                stopTimer()
                setFlash(on: false)
            }
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Pulsing Flashlight")
        
    }
    
    /// Replaces the timer with one at the current speed.
    func restartTimer() {
        stopTimer()
        let index = min(max(speed, 0), speeds.count - 1)
        let newTimer = Timer.publish(every: 1/speeds[index], on: .main, in: .common)
        timer = newTimer
        timerConnection = newTimer.connect()
    }

    func stopTimer() {
        timerConnection?.cancel()
        timerConnection = nil
    }

    func setFlash(on: Bool) {
        // Ask for the back camera explicitly, devices like iPhone Duo have cameras on several sides
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        guard device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if (on) {
                try? device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = AVCaptureDevice.TorchMode.off
            }

            device.unlockForConfiguration()
        } catch {
            // The torch is busy (e.g. used by the camera); skip this flash.
        }
    }
}

#Preview {
    PulsingFlashlight()
}
