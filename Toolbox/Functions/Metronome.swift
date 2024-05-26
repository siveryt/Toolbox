//
//  Metronome.swift
//  Toolbox
//
//  Created by Christian Nagel on 25.05.24.
//

import SwiftUI
import AVFoundation

struct Metronome: View {
    @AppStorage("metronome_bpm") private var bpm: Double = 120
    @AppStorage("metronome_bpmeasure") private var bpmeasure: Double = 4
    @State private var progress: Double = 0
    
    @AppStorage("metronome_progressFrom") private var progressFrom: [Double] = Array(repeating: 0, count: 16)
    @State private var beat: Int = 0
    
    @State private var fullscreen = false
    
    @State private var timer: Timer?
    @State private var isPlaying: Bool = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var tapTimes: [Date] = []

    @AppStorage("metronome_bpmString") private var bpmString: String = "120"
    @AppStorage("metronome_bpmeasureString") private var bpmeasureString: String = "4"
    
    var body: some View {
        Form {
            Section("Beats per Minute") {
                TextField("BPM", text: $bpmString)
                    .onChange(of: bpmString) { newValue in
                        // Attempt to convert the string to a double
                        if let value = Double(newValue) {
                            bpm = value
                        } else if (!bpmString.isEmpty) {
                            bpmString = String(bpm)
                        }
                        
                    }
                    .keyboardType(.numberPad)
                
                
                Slider(value: $bpm, in: 40...240, step: 1)
                    .onChange(of: bpm) { _ in
                        bpm = Double(Int(bpm))
                        if isPlaying {
                            restartMetronome()
                        }
                        bpmString = String(Int(bpm))
                    }
                
                Button(action: tapToSetBPM) {
                    Text("Tap to Set BPM")
                }
            }
            Section("Beats per Measure") {
                TextField("Beats per measure", text: $bpmeasureString)
                    .onChange(of: bpmeasureString) { newValue in
                        // Attempt to convert the string to a double
                        if let value = Double(newValue) {
                            bpmeasure = value
                        } else if (!bpmeasureString.isEmpty) {
                            bpmeasureString = String(bpmeasure)
                        }
                        
                    }
                    .keyboardType(.numberPad)
                
                
                Slider(value: $bpmeasure, in: 1...32, step: 1)
                    .onChange(of: bpmeasure) { _ in
                        bpmeasure = Double(Int(bpmeasure))
                        progressFrom = Array(repeating: 0, count: Int(bpmeasure))
                        if isPlaying {
                            restartMetronome()
                        }
                        bpmeasureString = String(Int(bpmeasure))
                    }
            }
            Section {
                Button(isPlaying ? "Stop":"Start") {
                    isPlaying.toggle()
                }
            }
            Section {
                HStack {
                    ForEach (0..<Int(bpmeasure), id: \.self) { i in
                        ProgressView(value: progressFrom[i], total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                            .scaleEffect(x: 1, y: 4, anchor: .center)
                    }
                }
                
            }
        }
        .fullScreenCover(isPresented: $fullscreen) {
            VStack {
                LazyVGrid(columns: Array.init(repeating: GridItem(), count: min(8, Int(bpmeasure))), spacing: 20.0) {
                    ForEach(0..<Int(bpmeasure), id: \.self) { i in
                        ProgressView(value: progressFrom[i], total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                            .scaleEffect(x: 1, y: 4, anchor: .center)
                    }
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onEnded { value in
                        fullscreen = false
                        isPlaying = false
                    }
            )
        }

        .toolbar {
            Button(action: {
                fullscreen = true
                isPlaying = true
            }, label: {
                Image(systemName: "arrow.down.left.and.arrow.up.right")
            })
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startMetronome()
            } else {
                stopMetronome()
            }
        }
        .onDisappear {
            stopMetronome()
        }
        .onAppear() {
            progressFrom = Array(repeating: 0, count: Int(bpmeasure))
        }
        .navigationTitle("Metronome")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startMetronome() {
        setupTimer()
    }

    private func stopMetronome() {
        timer?.invalidate()
        timer = nil
        progress = 0
        progressFrom = Array(repeating: 0, count: Int(bpmeasure))
    }
    
    private func restartMetronome() {
        stopMetronome()
        startMetronome()
    }

    private func setupTimer() {
        let interval = 60.0 / bpm
        timer = Timer.scheduledTimer(withTimeInterval: interval / 100, repeats: true) { _ in
            self.updateProgress()
        }
        playTickSound()
    }

    private func updateProgress() {
        progress += 0.01
        if progress >= bpmeasure {
            progress = 0
            progressFrom = Array(repeating: 0, count: Int(bpmeasure))
        }
        distributeProgress()
        if progress < 0.01 {
            playTickSound()
        } else if progress.truncatingRemainder(dividingBy: 1) < 0.01 {
            playTockSound()
        }
    }
    
    private func distributeProgress() {
        let index = Int(progress) % progressFrom.count
        progressFrom[index] = progress - floor(progress)
    }

    private func playTockSound() {
        DispatchQueue.main.async {
        guard let soundURL = Bundle.main.url(forResource: "tock", withExtension: "wav") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            print("Unable to play sound: \(error.localizedDescription)")
        }}
    }
    
    private func playTickSound() {
        DispatchQueue.main.async {
        guard let soundURL = Bundle.main.url(forResource: "tick", withExtension: "wav") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            print("Unable to play sound: \(error.localizedDescription)")
        }}
    }
    

    private func tapToSetBPM() {
        let now = Date()
        tapTimes.append(now)
        
        if tapTimes.count > 1 {
            let timeInterval = now.timeIntervalSince(tapTimes[tapTimes.count - 2])
            let calculatedBPM = 60.0 / timeInterval
            bpm = max(1, min(calculatedBPM, 1000))
            
            guard tapTimes.count > 1 else {
                print("Not enough dates to calculate intervals.")
                return
            }

            // Calculate the intervals between consecutive dates in seconds
            var intervals: [TimeInterval] = []
            for i in 1..<tapTimes.count {
                let interval = tapTimes[i].timeIntervalSince(tapTimes[i-1])
                intervals.append(interval)
            }

            // Calculate the average interval
            let totalInterval = intervals.reduce(0, +)
            let averageInterval = totalInterval / Double(intervals.count)
            
            bpm = max(10, min(60 / averageInterval, 500))
            
        }
        
        if tapTimes.count > 3 {
            tapTimes.removeFirst()
        }
    }
}

struct ButtonToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            configuration.label
                .padding()
                .background(configuration.isOn ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}
