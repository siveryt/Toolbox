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
    @Environment(\.scenePhase) private var scenePhase

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
                    Text(verbatim: "\((level * 100).formatted(.number.precision(.fractionLength(1)))) dB")
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
            // The microphone can't be used in the background; measure again when the app comes back.
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active: self.startMonitoring()
                case .background: self.stopMonitoring()
                default: break
                }
            }
            // A phone call or Siri takes the microphone; continue afterwards if the system allows it.
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
                guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
                switch type {
                case .began:
                    self.stopMonitoring()
                case .ended:
                    let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    if AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) {
                        self.startMonitoring()
                    }
                @unknown default:
                    break
                }
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
        // Never run two recorders or timers at once, e.g. when the app becomes active right after appearing.
        stopMonitoring()
        history = []
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // The measurement mode turns off automatic gain control and voice processing, which would flatten the levels.
            try audioSession.setCategory(.record, mode: .measurement)
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
            // The microphone isn't available (e.g. in use by a call); the level stays at its last value.
            stopMonitoring()
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
        audioRecorder = nil
        timer?.invalidate()
        timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Maps the recorder's average power (dBFS, 0 at full scale) linearly onto 0...1: -80 dBFS and below is 0, 0 dBFS is 1.
    /// Louder input never gives a lower value. The view shows this times 100 as "dB", which is only an uncalibrated
    /// approximation: it isn't dB SPL, and the real sound pressure for a given value depends on the device's microphone.
    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else { return 0.0 }
        let minDb: Float = -80
        return min(max((power - minDb) / -minDb, 0), 1)
    }
}
