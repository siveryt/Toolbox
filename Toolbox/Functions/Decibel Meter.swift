//
//  Decibel Meter.swift
//  Toolbox
//
//  Created by Christian Nagel on 25.05.24.
//

import SwiftUI
import AVFoundation
import Charts

struct DecibelMeter: View {
    @State private var audioRecorder: AVAudioRecorder?
    @State private var level: Float = 0.0
    @State private var timer: Timer?
    @State private var hasPermission: Bool = false
    @State private var permissionAsked: Bool = false
    /// The last ten seconds of levels for the graph, oldest first.
    @State private var history: [LevelSample] = []
    @State private var sampleCount = 0

    private struct LevelSample: Identifiable {
        let id: Int
        let level: Float
    }
    private let historyLength = 100

    var body: some View {
        if hasPermission {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    Text(String(format: "%.1f dB", level * 100))
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.8, design: .default)).monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.01)
                        .frame(maxWidth: .infinity)
                        .padding() // Adds default padding
                    
                    levelGraph
                        .frame(height: min(160, geometry.size.height * 0.25))
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
        } else {
            Group {
                if permissionAsked {
                    PermissionDeniedView(
                        title: NSLocalizedString("Microphone Access Required", comment: "Missing permission view: title when microphone access was denied"),
                        systemImage: "mic.slash",
                        description: NSLocalizedString("You first have to allow Toolbox to access your microphone to measure audio levels.", comment: "Decibel Meter: shown without microphone access")
                    )
                } else {
                    // The permission prompt is showing
                    Color.clear
                }
            }
            .onAppear {
                checkMicrophoneAccess()
                requestMicrophoneAccess()
            }
        }
    }

    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                self.hasPermission = granted
                self.permissionAsked = true
            }
        }
    }

    private func checkMicrophoneAccess() {
        self.hasPermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func startMonitoring() {
        history = []
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
                self.history.append(LevelSample(id: self.sampleCount, level: self.level))
                self.sampleCount += 1
                if self.history.count > self.historyLength {
                    self.history.removeFirst(self.history.count - self.historyLength)
                }
            }
        } catch {
            print("Failed to set up audio session and recorder: \(error.localizedDescription)")
        }
    }

    /// The levels of the last ten seconds, the newest on the right.
    private var levelGraph: some View {
        Chart(history) { sample in
            AreaMark(
                x: .value("Time", sample.id),
                y: .value("Level", sample.level * 100)
            )
            .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.monotone)
            LineMark(
                x: .value("Time", sample.id),
                y: .value("Level", sample.level * 100)
            )
            .foregroundStyle(Color.accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
        }
        .chartXScale(domain: (sampleCount - historyLength)...max(sampleCount - 1, 1))
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 50, 100]) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .accessibilityHidden(true)
    }

    private func stopMonitoring() {
        audioRecorder?.stop()
        timer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
