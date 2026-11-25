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
    
    /// Flashes per second, in hertz.
    @AppStorage("pulsingFlashlight_frequency") private var frequency = PulsingFlashlight.defaultFrequency
    @FocusState private var editingFrequency: Bool

    static let defaultFrequency = 0.5
    static let frequencyRange = 0.05...5.0
    /// Before the frequency in hertz, the speed was stored as an index into this list of timer ticks per second (two ticks per flash).
    static let legacySpeeds = [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1,2,3,4,5,6,7,8,9,10]

    /// Keeps typed values inside the range the flashlight can do.
    var frequencyBinding: Binding<Double> {
        Binding(get: { frequency }, set: { frequency = Self.clamp($0) })
    }

    /// The slider is logarithmic, so slow and fast frequencies both get room.
    var sliderBinding: Binding<Double> {
        Binding(get: { log(frequency) }, set: { frequency = Self.clamp(Self.roundToTwoDigits(exp($0))) })
    }

    @State var timer = Timer.publish(every: 1, on: .main, in: .common)
    /// The running timer; cancelling it stops the timer.
    @State private var timerConnection: Cancellable?
    
    /// iPads and the simulator have no torch, so there's nothing to pulse.
    let hasTorch = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)?.hasTorch ?? false

    var body: some View {
        
        Form {
            Section {
                Toggle(isOn: $enabled){
                    Text("Enabled")
                }
                .disabled(!hasTorch)
            } footer: {
                if !hasTorch {
                    Text(NSLocalizedString("This device has no flashlight.", comment: "Pulsing Flashlight: shown under the Enabled switch on devices without a flashlight, e.g. iPads"))
                }
            }
            .onChange(of: enabled) {
                if (!enabled) {
                    setFlash(on: false)
                }
            }
            
            Section {
                HStack {
                    Text(NSLocalizedString("Frequency", comment: "Pulsing Flashlight: label of the flash frequency (flashes per second)"))
                    Spacer()
                    TextField("", value: frequencyBinding, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($editingFrequency)
                        .frame(maxWidth: 70)
                        .accessibilityLabel(Text(NSLocalizedString("Frequency in hertz", comment: "Pulsing Flashlight: accessibility label of the text field for the flash frequency")))
                    Text(UnitFrequency.hertz.symbol)
                        .foregroundStyle(.secondary)
                }

                Slider(value: sliderBinding, in: log(Self.frequencyRange.lowerBound)...log(Self.frequencyRange.upperBound)) {
                    Text(NSLocalizedString("Frequency", comment: "Pulsing Flashlight: label of the flash frequency (flashes per second)"))
                } minimumValueLabel: {
                    Text(Self.format(Self.frequencyRange.lowerBound))
                } maximumValueLabel: {
                    Text(Self.format(Self.frequencyRange.upperBound))
                }
                .accessibilityValue(Text(Self.format(frequency)))
                .font(.caption)
                .foregroundStyle(.secondary)
            } footer: {
                Text(NSLocalizedString("How often the flashlight flashes per second, in hertz (Hz).", comment: "Pulsing Flashlight: explanation under the frequency setting"))
            }
            .onChange(of: frequency) {
                restartTimer()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    editingFrequency = false
                }
            }
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
            migrateLegacySpeed()
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
        // The timer toggles the torch, so it ticks twice per flash.
        let newTimer = Timer.publish(every: 1 / (2 * Self.clamp(frequency)), on: .main, in: .common)
        timer = newTimer
        timerConnection = newTimer.connect()
    }

    /// Takes over the speed saved by older versions, which stored an index instead of hertz.
    func migrateLegacySpeed() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "pulsingFlashlight_frequency") == nil,
              let index = defaults.object(forKey: "pulsingFlashlight_speed") as? Int else { return }
        let legacy = Self.legacySpeeds[min(max(index, 0), Self.legacySpeeds.count - 1)]
        frequency = Self.clamp(legacy / 2)
    }

    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return defaultFrequency }
        return min(max(value, frequencyRange.lowerBound), frequencyRange.upperBound)
    }

    /// Rounds to two significant digits, so the slider gives 0.12 Hz or 2.5 Hz instead of 2.4871 Hz.
    static func roundToTwoDigits(_ value: Double) -> Double {
        guard value > 0 else { return value }
        let step = pow(10, floor(log10(value)) - 1)
        return (value / step).rounded() * step
    }

    static func format(_ value: Double) -> String {
        Measurement(value: value, unit: UnitFrequency.hertz)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...2))))
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
