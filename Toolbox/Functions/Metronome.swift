//
//  Metronome.swift
//  Toolbox
//
//  Created by Christian Nagel on 25.05.24.
//

import SwiftUI
import AVFoundation
import QuartzCore
import TipKit

/// Hint shown in the metronome's full-screen mode explaining how to exit it.
struct MetronomeFullscreenTip: Tip {
    var title: Text {
        Text("Exit Fullscreen")
    }
    var message: Text? {
        Text("Tap anywhere to minimize")
    }
    var image: Image? {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
    }
}

/// Plays the clicks with AVAudioEngine, scheduled ahead on the audio clock, so they keep time
/// while the UI is busy. Times are host time in seconds (`CACurrentMediaTime`).
@Observable
final class MetronomeEngine {
    static let bpmRange = 30.0...300.0

    var bpm: Double = 120 {
        didSet { if bpm != oldValue { tempoChanged(from: oldValue) } }
    }
    var beatsPerMeasure = 4
    private(set) var isPlaying = false

    /// From `time` on, beats follow every 60 / `bpm` seconds, with beat number `beat` (may be fractional) at `time`.
    private struct Segment {
        var beat: Double
        var time: CFTimeInterval
        var bpm: Double
    }

    @ObservationIgnored private let engine = AVAudioEngine()
    // The click sounds are longer than a beat at fast tempos, and a player node plays its buffers one after another,
    // so the clicks rotate through a few nodes to let them overlap.
    @ObservationIgnored private var players: [AVAudioPlayerNode] = []
    @ObservationIgnored private var nextPlayer = 0
    @ObservationIgnored private var accentSound: AVAudioPCMBuffer?
    @ObservationIgnored private var beatSound: AVAudioPCMBuffer?
    @ObservationIgnored private var segments: [Segment] = []
    @ObservationIgnored private var nextBeat = 0
    @ObservationIgnored private var scheduler: Timer?
    @ObservationIgnored private var outputLatency: TimeInterval = 0
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private let lookahead: TimeInterval = 0.2

    /// Sets up the audio graph on first use; SwiftUI creates a throwaway instance on every view update.
    private func setUpIfNeeded() {
        guard players.isEmpty else { return }
        accentSound = Self.loadSound("tick")
        beatSound = Self.loadSound("tock")
        guard let format = accentSound?.format else { return }
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        // A phone call, Siri or a changed audio route stops the engine; stop the metronome with it.
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.stop()
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        scheduler?.invalidate()
        engine.stop()
    }

    private static func loadSound(_ name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return nil }
        return buffer
    }

    func toggle() {
        isPlaying ? stop() : start()
    }

    func start() {
        guard !isPlaying else { return }
        setUpIfNeeded()
        guard !players.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback plays with the silent switch on; mixWithOthers lets music keep playing along.
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
            try engine.start()
        } catch {
            // The audio session or engine isn't available (e.g. during a call); stay stopped.
            return
        }
        outputLatency = session.outputLatency
        players.forEach { $0.play() }
        segments = [Segment(beat: 0, time: CACurrentMediaTime() + 0.1, bpm: bpm)]
        nextBeat = 0
        isPlaying = true
        scheduleBeats()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.scheduleBeats()
        }
        // .common keeps it firing while a slider is dragged.
        RunLoop.main.add(timer, forMode: .common)
        scheduler = timer
    }

    func stop() {
        guard isPlaying else { return }
        scheduler?.invalidate()
        scheduler = nil
        players.forEach { $0.stop() }
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        segments = []
        isPlaying = false
    }

    private func time(ofBeat beat: Int) -> CFTimeInterval {
        let segment = segments.last { $0.beat <= Double(beat) } ?? segments[0]
        return segment.time + (Double(beat) - segment.beat) * 60 / segment.bpm
    }

    /// The beat number at `time`, counting from 0 at the first click; nil when stopped or before the first click.
    private func position(at time: CFTimeInterval) -> Double? {
        guard let segment = segments.last(where: { $0.time <= time }) else { return nil }
        return segment.beat + (time - segment.time) * segment.bpm / 60
    }

    private func scheduleBeats() {
        guard isPlaying else { return }
        let horizon = CACurrentMediaTime() + lookahead
        while time(ofBeat: nextBeat) < horizon {
            let sound = nextBeat % max(beatsPerMeasure, 1) == 0 ? accentSound : beatSound
            if let sound {
                let at = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: time(ofBeat: nextBeat)))
                players[nextPlayer].scheduleBuffer(sound, at: at)
                nextPlayer = (nextPlayer + 1) % players.count
            }
            nextBeat += 1
        }
    }

    /// Continues from the current position at the new tempo. Beats already handed to the audio engine keep their time,
    /// so the new tempo starts right after the last of them.
    private func tempoChanged(from oldBPM: Double) {
        guard isPlaying, let first = segments.first else { return }
        let lastScheduled = nextBeat > 0 ? time(ofBeat: nextBeat - 1) : first.time
        let start = max(CACurrentMediaTime(), lastScheduled)
        guard let beat = position(at: start) else {
            // Not started yet: begin at the new tempo.
            segments = [Segment(beat: 0, time: first.time, bpm: bpm)]
            return
        }
        let segment = Segment(beat: beat, time: start, bpm: bpm)
        if let last = segments.last, last.time == start {
            // Several changes before the next beat (e.g. dragging the slider) start at the same moment; only the latest tempo counts.
            segments[segments.count - 1] = segment
        } else {
            segments.append(segment)
        }
        if segments.count > 3 { segments.removeFirst(segments.count - 3) }
    }

    /// How far each beat of the current measure has filled, from 0 to 1, for the moment that's audible now.
    func beatFill() -> [Double] {
        let count = max(beatsPerMeasure, 1)
        guard isPlaying, let position = position(at: CACurrentMediaTime() - outputLatency) else {
            return Array(repeating: 0, count: count)
        }
        let beat = Int(position.rounded(.down))
        let current = beat % count
        let fraction = position - Double(beat)
        return (0..<count).map { $0 < current ? 1 : ($0 == current ? fraction : 0) }
    }
}

/// One bar per beat of the measure, the current beat filling up as it passes.
private struct BeatBars: View {
    let engine: MetronomeEngine
    var columns: Int? = nil
    var barHeight: CGFloat = 10

    var body: some View {
        TimelineView(.animation(paused: !engine.isPlaying)) { _ in
            let fill = engine.beatFill()
            if let columns {
                LazyVGrid(columns: Array(repeating: GridItem(spacing: 12), count: min(columns, fill.count)), spacing: 24) {
                    bars(fill)
                }
            } else {
                HStack(spacing: fill.count > 16 ? 3 : 6) {
                    bars(fill)
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func bars(_ fill: [Double]) -> some View {
        ForEach(fill.indices, id: \.self) { i in
            ZStack(alignment: .leading) {
                Rectangle().fill(.fill.tertiary)
                Rectangle()
                    .fill(Color.accentColor)
                    .scaleEffect(x: fill[i], y: 1, anchor: .leading)
            }
            .frame(height: barHeight)
            .clipShape(Capsule())
        }
    }
}

struct Metronome: View {
    private let fullscreenTip = MetronomeFullscreenTip()

    @AppStorage("metronome_bpm") private var bpm: Double = 120
    @AppStorage("metronome_bpmeasure") private var bpmeasure: Double = 4

    @State private var engine = MetronomeEngine()
    @State private var fullscreen = false
    @State private var tapTimes: [Date] = []

    @AppStorage("metronome_bpmString") private var bpmString: String = "120"
    @AppStorage("metronome_bpmeasureString") private var bpmeasureString: String = "4"
    @FocusState private var bpmFieldFocused: Bool
    @FocusState private var bpmeasureFieldFocused: Bool

    var body: some View {
        Form {
            Section("Beats per Minute") {
                TextField("BPM", text: $bpmString)
                    .onChange(of: bpmString) {
                        // Only take values in range, so typing "1" on the way to "120" doesn't jump the tempo
                        if let value = Double(bpmString), MetronomeEngine.bpmRange.contains(value) {
                            bpm = value
                        }
                    }
                    .keyboardType(.numberPad)
                    .focused($bpmFieldFocused)
                    .onChange(of: bpmFieldFocused) {
                        // Show the tempo that's actually used once editing ends, not an out-of-range entry
                        if !bpmFieldFocused { bpmString = String(Int(bpm)) }
                    }

                Slider(value: $bpm, in: MetronomeEngine.bpmRange, step: 1)
                    .onChange(of: bpm) {
                        bpm = bpm.rounded()
                        engine.bpm = bpm
                        if Double(bpmString) != bpm {
                            bpmString = String(Int(bpm))
                        }
                    }

                Button(action: tapToSetBPM) {
                    Text("Tap to Set BPM")
                }
            }
            Section("Beats per Measure") {
                TextField("Beats per measure", text: $bpmeasureString)
                    .onChange(of: bpmeasureString) {
                        if let value = Double(bpmeasureString), (1...32).contains(value) {
                            bpmeasure = value
                        }
                    }
                    .keyboardType(.numberPad)
                    .focused($bpmeasureFieldFocused)
                    .onChange(of: bpmeasureFieldFocused) {
                        if !bpmeasureFieldFocused { bpmeasureString = String(Int(bpmeasure)) }
                    }

                Slider(value: $bpmeasure, in: 1...32, step: 1)
                    .onChange(of: bpmeasure) {
                        bpmeasure = bpmeasure.rounded()
                        engine.beatsPerMeasure = Int(bpmeasure)
                        if Double(bpmeasureString) != bpmeasure {
                            bpmeasureString = String(Int(bpmeasure))
                        }
                    }
            }
            Section {
                Button(engine.isPlaying ? "Stop" : "Start") {
                    engine.toggle()
                }
            }
            Section {
                BeatBars(engine: engine)
                    .padding(.vertical, 6)
            }
        }
        .fullScreenCover(isPresented: $fullscreen) {
            BeatBars(engine: engine, columns: 8, barHeight: 16)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    fullscreen = false
                    engine.stop()
                    fullscreenTip.invalidate(reason: .actionPerformed)
                }
                .overlay(alignment: .top) {
                    TipView(fullscreenTip)
                        .padding()
                }
        }
        .toolbar {
            Button(action: {
                fullscreen = true
                engine.start()
            }, label: {
                Image(systemName: "arrow.down.left.and.arrow.up.right")
            })
        }
        .onAppear {
            bpm = min(max(bpm, MetronomeEngine.bpmRange.lowerBound), MetronomeEngine.bpmRange.upperBound).rounded()
            bpmeasure = min(max(bpmeasure, 1), 32).rounded()
            engine.bpm = bpm
            engine.beatsPerMeasure = Int(bpmeasure)
            // The fields are persisted as typed, possibly out of range; show the values that are used.
            syncFieldsToValues()
        }
        .onDisappear {
            // The full-screen cover also makes the form disappear; keep playing there.
            if !fullscreen {
                engine.stop()
            }
        }
        .navigationTitle("Metronome")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Puts the values that are actually used back into the text fields.
    private func syncFieldsToValues() {
        bpmString = String(Int(bpm))
        bpmeasureString = String(Int(bpmeasure))
    }

    private func tapToSetBPM() {
        let now = Date()
        // A pause of more than two seconds starts a new measurement
        if let last = tapTimes.last, now.timeIntervalSince(last) > 2 {
            tapTimes.removeAll()
        }
        tapTimes.append(now)
        if tapTimes.count > 4 {
            tapTimes.removeFirst()
        }
        guard tapTimes.count > 1, let first = tapTimes.first else { return }

        let averageInterval = now.timeIntervalSince(first) / Double(tapTimes.count - 1)
        bpm = min(max(60 / averageInterval, MetronomeEngine.bpmRange.lowerBound), MetronomeEngine.bpmRange.upperBound)
    }
}
