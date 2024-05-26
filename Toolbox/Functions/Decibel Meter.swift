//
//  Decibel Meter.swift
//  Toolbox
//
//  Created by Christian Nagel on 25.05.24.
//

import SwiftUI
import AVFoundation

struct DecibelMeter: View {
    @State private var audioRecorder: AVAudioRecorder?
    @State private var level: Float = 0.0
    @State private var timer: Timer?

    var body: some View {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    Text(String(format: "%.1f dB", level * 100))
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.8, design: .default)).monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.01)
                        .frame(maxWidth: .infinity)
                        .padding() // Adds default padding
                    
                    ProgressView(value: level, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        .scaleEffect(x: 1, y: 4, anchor: .center)
                        .padding()
                    Spacer()
                    Spacer()
                }
            }
            .onAppear {
                self.startMonitoring()
            }
            .onDisappear {
                self.stopMonitoring()
            }
        default:
            VStack{
                Text("You first have to allow Toolbox to access your microphone to measure audio levels.")
                Button("Open Settings") {
                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                    }
                }
            }
        }
        
        
    }

    private func startMonitoring() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession.setActive(true)

            let settings = [
                AVFormatIDKey: kAudioFormatAppleLossless,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ] as [String : Any]

            audioRecorder = try AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.audioRecorder?.updateMeters()
                self.level = self.scaledPower(power: self.audioRecorder?.averagePower(forChannel: 0) ?? -160)
            }
        } catch {
            print("Failed to set up audio session and recorder: \(error.localizedDescription)")
        }
    }

    private func stopMonitoring() {
        audioRecorder?.stop()
        timer?.invalidate()
    }

    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else { return 0.0 }
        let minDb: Float = -80
        if power < minDb {
            return 0.0
        } else if power >= 0 {
            return 1.0
        } else {
            return (abs(minDb) - abs(power)) / abs(minDb)
        }
    }
}
