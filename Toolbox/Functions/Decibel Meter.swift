//
//  Decibel Meter.swift
//  Toolbox
//
//  Created by Christian Nagel on 25.05.24.
//

import SwiftUI
import AVFoundation
import Accelerate
import Charts

/// Frequency weighting of the level, as defined in IEC 61672-1.
enum DecibelWeighting: String, CaseIterable, Identifiable {
    case a, c, z

    var id: Self { self }

    /// The unit shown after the level, e.g. "dB(A)".
    var unit: String {
        switch self {
        case .a: "dB(A)"
        case .c: "dB(C)"
        case .z: "dB(Z)"
        }
    }

    var title: String {
        switch self {
        case .a: NSLocalizedString("A (human hearing)", comment: "Decibel Meter settings: option for A frequency weighting")
        case .c: NSLocalizedString("C (with bass)", comment: "Decibel Meter settings: option for C frequency weighting")
        case .z: NSLocalizedString("Z (unweighted)", comment: "Decibel Meter settings: option for Z frequency weighting, i.e. no weighting")
        }
    }

    /// Short description below the level.
    var caption: String {
        switch self {
        case .a: NSLocalizedString("A-weighted", comment: "Decibel Meter: below the level, the level is A-weighted")
        case .c: NSLocalizedString("C-weighted", comment: "Decibel Meter: below the level, the level is C-weighted")
        case .z: NSLocalizedString("Unweighted", comment: "Decibel Meter: below the level, the level is Z-weighted, i.e. not weighted")
        }
    }

    /// The weighting's gain at `frequency` (Hz) as a factor on the amplitude, 1 at 1 kHz.
    func gain(at frequency: Double) -> Double {
        let f2 = frequency * frequency
        switch self {
        case .a:
            let ra = pow(12194.0, 2) * f2 * f2
                / ((f2 + pow(20.6, 2)) * sqrt((f2 + pow(107.7, 2)) * (f2 + pow(737.9, 2))) * (f2 + pow(12194.0, 2)))
            return ra * pow(10, 2.0 / 20)
        case .c:
            let rc = pow(12194.0, 2) * f2 / ((f2 + pow(20.6, 2)) * (f2 + pow(12194.0, 2)))
            return rc * pow(10, 0.062 / 20)
        case .z:
            return 1
        }
    }
}

/// Time weighting of the level, as defined in IEC 61672-1.
enum DecibelTimeWeighting: String, CaseIterable, Identifiable {
    case fast, slow

    var id: Self { self }

    /// The time constant in seconds.
    var timeConstant: Double {
        switch self {
        case .fast: 0.125
        case .slow: 1
        }
    }

    var title: String {
        switch self {
        case .fast: NSLocalizedString("Fast (125 ms)", comment: "Decibel Meter settings: option for the Fast time weighting")
        case .slow: NSLocalizedString("Slow (1 s)", comment: "Decibel Meter settings: option for the Slow time weighting")
        }
    }

    /// Short description below the level.
    var caption: String {
        switch self {
        case .fast: NSLocalizedString("Fast", comment: "Decibel Meter: below the level, the Fast time weighting (technical term of sound level meters)")
        case .slow: NSLocalizedString("Slow", comment: "Decibel Meter: below the level, the Slow time weighting (technical term of sound level meters)")
        }
    }
}

/// Measures the microphone with AVAudioEngine: the level in every weighting, and the spectrum in logarithmic bands.
/// The audio is analyzed on the tap's thread; everything observed is changed on the main thread.
@Observable
final class DecibelAnalyzer {
    /// Samples per FFT; at 48 kHz this resolves about 12 Hz.
    static let fftSize = 4096
    static let bandCount = 64
    static let minFrequency = 20.0
    /// Ten seconds of levels and spectrogram columns at one per `tickInterval`.
    static let historyLength = 100
    static let tickInterval = 0.1
    /// What 0 dBFS (the loudest the microphone can record) is shown as.
    static let displayOffset: Float = 100
    /// The spectrum and spectrogram show band levels in this range (dBFS).
    static let spectrumRange: ClosedRange<Float> = -100 ... -20

    struct LevelSample: Identifiable {
        let id: Int
        let level: Float
    }

    var weighting: DecibelWeighting = .a
    var timeWeighting: DecibelTimeWeighting = .fast

    /// The current level as shown, about 0...100.
    private(set) var level: Float = 0
    /// The last ten seconds of levels, oldest first.
    private(set) var history: [LevelSample] = []
    private(set) var sampleCount = 0
    /// The current level of each band in dBFS, lowest frequency first.
    private(set) var spectrum: [Float] = Array(repeating: DecibelAnalyzer.spectrumRange.lowerBound, count: DecibelAnalyzer.bandCount)
    /// The center frequency of each band.
    private(set) var bandFrequencies: [Double] = DecibelAnalyzer.bandCenters(maxFrequency: 20000)
    /// The highest frequency shown, limited by the sample rate.
    private(set) var maxFrequency = 20000.0
    /// The spectrum over the last ten seconds: time from left to right, frequency from bottom to top.
    private(set) var spectrogram: CGImage?

    // Main thread
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isRunning = false
    /// Mean square of the input per weighting and time weighting, exponentially averaged.
    @ObservationIgnored private var smoothed: [DecibelWeighting: [DecibelTimeWeighting: Float]] = [:]
    @ObservationIgnored private var spectrogramColumns: [[Float]] = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    // Tap thread (set up before the tap is installed)
    @ObservationIgnored private var samples: [Float] = []
    @ObservationIgnored private var window: [Float] = []
    @ObservationIgnored private var windowed: [Float] = []
    @ObservationIgnored private var power: [Float] = []
    @ObservationIgnored private var realp: [Float] = []
    @ObservationIgnored private var imagp: [Float] = []
    @ObservationIgnored private var fftSetup: FFTSetup?
    /// Squared gain of each FFT bin per weighting.
    @ObservationIgnored private var binGains: [DecibelWeighting: [Float]] = [:]
    /// The FFT bins that make up each band.
    @ObservationIgnored private var bandBins: [ClosedRange<Int>] = []

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        timer?.invalidate()
        engine.stop()
        if let fftSetup { vDSP_destroy_fftsetup(fftSetup) }
    }

    func start() {
        // Never run two taps or timers at once, e.g. when the app becomes active right after appearing.
        stop()
        let session = AVAudioSession.sharedInstance()
        do {
            // The measurement mode turns off automatic gain control and voice processing, which would flatten the levels.
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            // Without a microphone (e.g. in some simulators) the format is empty, and installing a tap would crash.
            guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.featureUnsupported) }
            prepare(sampleRate: format.sampleRate)
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(Self.fftSize), format: format) { [weak self] buffer, _ in
                self?.analyze(buffer)
            }
            try engine.start()
        } catch {
            // The microphone isn't available (e.g. in use by a call); the level stays at its last value.
            stop()
            return
        }
        isRunning = true
        if observers.isEmpty {
            // Plugging in a headset changes the input and stops the engine; continue with the new one.
            observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.start()
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Clears the measurements and sets up the FFT for `sampleRate`.
    private func prepare(sampleRate: Double) {
        let n = Self.fftSize
        let half = n / 2
        smoothed = [:]
        history = []
        spectrogramColumns = []
        spectrogram = nil
        spectrum = Array(repeating: Self.spectrumRange.lowerBound, count: Self.bandCount)

        samples = Array(repeating: 0, count: n)
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: n, isHalfWindow: false)
        windowed = Array(repeating: 0, count: n)
        power = Array(repeating: 0, count: half)
        realp = Array(repeating: 0, count: half)
        imagp = Array(repeating: 0, count: half)
        if fftSetup == nil {
            fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Double(n))), FFTRadix(kFFTRadix2))
        }

        let binWidth = sampleRate / Double(n)
        for weighting in DecibelWeighting.allCases {
            binGains[weighting] = (0..<half).map { Float(pow(weighting.gain(at: Double($0) * binWidth), 2)) }
        }

        maxFrequency = min(20000, sampleRate / 2)
        bandFrequencies = Self.bandCenters(maxFrequency: maxFrequency)
        let ratio = pow(maxFrequency / Self.minFrequency, 1 / Double(Self.bandCount))
        bandBins = (0..<Self.bandCount).map { band in
            let low = Self.minFrequency * pow(ratio, Double(band))
            let first = max(1, Int((low / binWidth).rounded(.up)))
            let last = min(half - 1, Int((low * ratio / binWidth).rounded(.down)))
            if first <= last { return first...last }
            // Low bands are narrower than a bin; use the bin closest to the band's center.
            let nearest = min(half - 1, max(1, Int((low * sqrt(ratio) / binWidth).rounded())))
            return nearest...nearest
        }
    }

    /// Logarithmically spaced band centers from `minFrequency` to `maxFrequency`.
    private static func bandCenters(maxFrequency: Double) -> [Double] {
        let ratio = pow(maxFrequency / minFrequency, 1 / Double(bandCount))
        return (0..<bandCount).map { minFrequency * pow(ratio, Double($0) + 0.5) }
    }

    /// Runs on the tap's thread.
    private func analyze(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0], let fftSetup else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        let n = Self.fftSize
        let half = n / 2

        var meanSquare: Float = 0
        vDSP_measqv(data, 1, &meanSquare, vDSP_Length(count))

        // Keep the newest `fftSize` samples.
        let input = UnsafeBufferPointer(start: data, count: count)
        if count >= n {
            samples = Array(input.suffix(n))
        } else {
            samples.removeFirst(count)
            samples.append(contentsOf: input)
        }

        vDSP.multiply(samples, window, result: &windowed)
        realp.withUnsafeMutableBufferPointer { realp in
            imagp.withUnsafeMutableBufferPointer { imagp in
                var split = DSPSplitComplex(realp: realp.baseAddress!, imagp: imagp.baseAddress!)
                windowed.withUnsafeBufferPointer { windowed in
                    windowed.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, vDSP_Length(log2(Double(n))), FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &power, 1, vDSP_Length(half))
            }
        }
        // Bin 0 holds DC and the Nyquist frequency together.
        power[0] = 0

        // The weightings scale the level by how much they let through of the current spectrum.
        let total = vDSP.sum(power)
        var weightedMeanSquares: [DecibelWeighting: Float] = [:]
        for weighting in DecibelWeighting.allCases {
            guard weighting != .z, total > 0, let gains = binGains[weighting] else {
                weightedMeanSquares[weighting] = meanSquare
                continue
            }
            weightedMeanSquares[weighting] = meanSquare * vDSP.dot(power, gains) / total
        }

        // vDSP's FFT is twice the DFT, and the Hann window halves the amplitude: a full-scale sine reaches (n / 2)².
        let fullScale = Float(half * half)
        let bands = bandBins.map { bins in
            10 * log10(max(power[bins].max() ?? 0, 1e-20) / fullScale)
        }

        let duration = Double(count) / buffer.format.sampleRate
        DispatchQueue.main.async { [weak self] in
            self?.receive(meanSquares: weightedMeanSquares, bands: bands, duration: duration)
        }
    }

    private func receive(meanSquares: [DecibelWeighting: Float], bands: [Float], duration: Double) {
        guard isRunning else { return }
        for (weighting, meanSquare) in meanSquares {
            for timeWeighting in DecibelTimeWeighting.allCases {
                // Start at the first measurement instead of rising from silence.
                guard let previous = smoothed[weighting]?[timeWeighting] else {
                    smoothed[weighting, default: [:]][timeWeighting] = meanSquare
                    continue
                }
                let alpha = Float(1 - exp(-duration / timeWeighting.timeConstant))
                smoothed[weighting, default: [:]][timeWeighting] = previous + alpha * (meanSquare - previous)
            }
        }
        spectrum = bands
    }

    /// Updates what is shown, ten times a second.
    private func tick() {
        guard let meanSquare = smoothed[weighting]?[timeWeighting] else { return }
        level = max(0, 10 * log10(max(meanSquare, 1e-20)) + Self.displayOffset)
        history.append(LevelSample(id: sampleCount, level: level))
        sampleCount += 1
        if history.count > Self.historyLength {
            history.removeFirst(history.count - Self.historyLength)
        }
        spectrogramColumns.append(spectrum)
        if spectrogramColumns.count > Self.historyLength {
            spectrogramColumns.removeFirst(spectrogramColumns.count - Self.historyLength)
        }
        spectrogram = makeSpectrogram()
    }

    /// One pixel per band and tick; columns that haven't been measured yet stay transparent.
    private func makeSpectrogram() -> CGImage? {
        let width = Self.historyLength
        let height = Self.bandCount
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let offset = width - spectrogramColumns.count
        let range = Self.spectrumRange
        for (index, column) in spectrogramColumns.enumerated() {
            let x = offset + index
            for (band, level) in column.enumerated() {
                let value = min(max((level - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
                let (r, g, b, a) = Self.color(for: value)
                let pixel = ((height - 1 - band) * width + x) * 4
                // Premultiplied alpha
                pixels[pixel] = UInt8(r * a * 255)
                pixels[pixel + 1] = UInt8(g * a * 255)
                pixels[pixel + 2] = UInt8(b * a * 255)
                pixels[pixel + 3] = UInt8(a * 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }

    /// Quiet is transparent, then purple, red, orange and pale yellow for the loudest.
    private static func color(for value: Float) -> (Float, Float, Float, Float) {
        let stops: [(position: Float, r: Float, g: Float, b: Float)] = [
            (0, 0.25, 0.05, 0.55),
            (0.45, 0.85, 0.15, 0.35),
            (0.75, 1, 0.55, 0.1),
            (1, 1, 0.95, 0.6),
        ]
        let alpha = min(value * 2, 1)
        guard let upper = stops.firstIndex(where: { $0.position >= value }), upper > 0 else {
            return (stops[0].r, stops[0].g, stops[0].b, alpha)
        }
        let a = stops[upper - 1], b = stops[upper]
        let t = (value - a.position) / (b.position - a.position)
        return (a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, alpha)
    }
}

struct DecibelMeter: View {
    @State private var analyzer = DecibelAnalyzer()
    @State private var hasPermission: Bool = false
    @State private var permissionAsked: Bool = false
    @State private var settingsSheet = false
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("decibelWeighting") private var weighting: DecibelWeighting = .a
    @AppStorage("decibelTimeWeighting") private var timeWeighting: DecibelTimeWeighting = .fast
    @AppStorage("decibelShowLevelGraph") private var showLevelGraph = true
    @AppStorage("decibelShowSpectrum") private var showSpectrum = false
    @AppStorage("decibelShowSpectrogram") private var showSpectrogram = true

    var body: some View {
        Group {
            if hasPermission {
                meter
            } else if permissionAsked {
                PermissionDeniedView(
                    title: NSLocalizedString("Microphone Access Required", comment: "Missing permission view: title when microphone access was denied"),
                    systemImage: "mic.slash",
                    description: NSLocalizedString("You first have to allow Toolbox to access your microphone to measure audio levels.", comment: "Decibel Meter: shown without microphone access")
                )
            } else {
                // The permission prompt is showing
                Color.clear
                    .onAppear {
                        checkMicrophoneAccess()
                        requestMicrophoneAccess()
                    }
            }
        }
        .navigationTitle("Decibel Meter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    settingsSheet = true
                } label: {
                    Image(systemName: "gear")
                }
                .accessibilityLabel(Text("Settings"))
            }
        }
        .sheet(isPresented: $settingsSheet) {
            settings
        }
    }

    private var graphCount: Int {
        [showLevelGraph, showSpectrum, showSpectrogram].filter { $0 }.count
    }

    private var meter: some View {
        GeometryReader { geometry in
            let graphHeight = graphCount == 0 ? 0 : min(160, geometry.size.height * 0.6 / CGFloat(graphCount))
            let numberHeight = geometry.size.height - (graphHeight + 16) * CGFloat(graphCount)
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    Text(verbatim: "\(analyzer.level.formatted(.number.precision(.fractionLength(1)))) \(weighting.unit)")
                        .font(.system(size: max(min(geometry.size.width * 0.3, numberHeight * 0.5), 10))).monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.01)
                        .frame(maxWidth: .infinity)
                    Text(verbatim: [
                        weighting.caption,
                        timeWeighting.caption,
                        NSLocalizedString("not calibrated", comment: "Decibel Meter: below the level, the measurement isn't calibrated against a real sound level meter"),
                    ].joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .onTapGesture { settingsSheet = true }
                }
                .padding(.horizontal)
                Spacer(minLength: 0)
                if showLevelGraph {
                    levelGraph.frame(height: graphHeight)
                }
                if showSpectrum {
                    spectrumGraph.frame(height: graphHeight)
                }
                if showSpectrogram {
                    spectrogramGraph.frame(height: graphHeight)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onAppear {
            analyzer.weighting = weighting
            analyzer.timeWeighting = timeWeighting
            analyzer.start()
        }
        .onDisappear {
            analyzer.stop()
        }
        .onChange(of: weighting) { analyzer.weighting = weighting }
        .onChange(of: timeWeighting) { analyzer.timeWeighting = timeWeighting }
        // The microphone can't be used in the background; measure again when the app comes back.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: analyzer.start()
            case .background: analyzer.stop()
            default: break
            }
        }
        // A phone call or Siri takes the microphone; continue afterwards if the system allows it.
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
            switch type {
            case .began:
                analyzer.stop()
            case .ended:
                let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) {
                    analyzer.start()
                }
            @unknown default:
                break
            }
        }
    }

    /// The levels of the last ten seconds, the newest on the right.
    private var levelGraph: some View {
        Chart(analyzer.history) { sample in
            AreaMark(
                x: .value("Time", sample.id),
                y: .value("Level", min(sample.level, 100))
            )
            .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.monotone)
            LineMark(
                x: .value("Time", sample.id),
                y: .value("Level", min(sample.level, 100))
            )
            .foregroundStyle(Color.accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
        }
        .chartXScale(domain: (analyzer.sampleCount - DecibelAnalyzer.historyLength)...max(analyzer.sampleCount - 1, 1))
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

    /// How loud each frequency is right now.
    private var spectrumGraph: some View {
        let range = DecibelAnalyzer.spectrumRange
        return Chart(analyzer.spectrum.indices, id: \.self) { band in
            let frequency = analyzer.bandFrequencies[band]
            // Measured from the bottom of the range, since an area is filled down to 0.
            let height = min(max(analyzer.spectrum[band], range.lowerBound), range.upperBound) - range.lowerBound
            AreaMark(
                x: .value(NSLocalizedString("Frequency", comment: "Decibel Meter: label of the frequency axis of the spectrum graph (not shown, used by the chart)"), frequency),
                y: .value("Level", height)
            )
            .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.1)], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.monotone)
            LineMark(
                x: .value(NSLocalizedString("Frequency", comment: "Decibel Meter: label of the frequency axis of the spectrum graph (not shown, used by the chart)"), frequency),
                y: .value("Level", height)
            )
            .foregroundStyle(Color.accentColor)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
        }
        .chartXScale(domain: DecibelAnalyzer.minFrequency...analyzer.maxFrequency, type: .log)
        .chartYScale(domain: 0...(range.upperBound - range.lowerBound))
        .chartXAxis {
            AxisMarks(values: [100, 1000, 10000]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let frequency = value.as(Double.self) {
                        Text(verbatim: Self.frequencyLabel(frequency))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .animation(.linear(duration: DecibelAnalyzer.tickInterval), value: analyzer.spectrum)
        .accessibilityHidden(true)
    }

    /// The spectrum of the last ten seconds, the newest on the right.
    private var spectrogramGraph: some View {
        let frequencies: [Double] = [100, 1000, 10000]
        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.fill.quaternary)
                if let image = analyzer.spectrogram {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.medium)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                ForEach(frequencies, id: \.self) { frequency in
                    let position = log(frequency / DecibelAnalyzer.minFrequency) / log(analyzer.maxFrequency / DecibelAnalyzer.minFrequency)
                    let y = geometry.size.height * (1 - position)
                    Text(verbatim: Self.frequencyLabel(frequency))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .background(.background.opacity(0.6), in: Capsule())
                        .position(x: geometry.size.width - 24, y: y)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private static func frequencyLabel(_ frequency: Double) -> String {
        frequency >= 1000 ? "\(Int(frequency / 1000)) kHz" : "\(Int(frequency)) Hz"
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(NSLocalizedString("Frequency Weighting", comment: "Decibel Meter settings: picker for the frequency weighting (A, C or Z)"), selection: $weighting) {
                        ForEach(DecibelWeighting.allCases) { weighting in
                            Text(weighting.title).tag(weighting)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(NSLocalizedString("Frequency Weighting", comment: "Decibel Meter settings: picker for the frequency weighting (A, C or Z)"))
                } footer: {
                    Text(NSLocalizedString("A-weighting matches how loud people perceive sounds and is used for noise limits. C-weighting includes more of the bass, Z-weighting counts all frequencies equally.", comment: "Decibel Meter settings: footer explaining the frequency weightings"))
                }
                Section {
                    Picker(NSLocalizedString("Time Weighting", comment: "Decibel Meter settings: picker for the time weighting (Fast or Slow)"), selection: $timeWeighting) {
                        ForEach(DecibelTimeWeighting.allCases) { timeWeighting in
                            Text(timeWeighting.title).tag(timeWeighting)
                        }
                    }
                } footer: {
                    Text(NSLocalizedString("Fast follows changes within 125 ms, Slow averages over a second.\n\nThe level is relative to the loudest sound the microphone can record, which is shown as 100 dB. It isn't calibrated, so it can differ from a real sound level meter.", comment: "Decibel Meter settings: footer explaining the time weightings and that the level isn't calibrated"))
                }
                Section {
                    Toggle(NSLocalizedString("Level History", comment: "Decibel Meter settings: toggle for the graph of the level over the last ten seconds"), isOn: $showLevelGraph)
                    Toggle(NSLocalizedString("Spectrum", comment: "Decibel Meter settings: toggle for the graph of how loud each frequency is right now"), isOn: $showSpectrum)
                    Toggle(NSLocalizedString("Spectrogram", comment: "Decibel Meter settings: toggle for the graph of the frequencies over the last ten seconds"), isOn: $showSpectrogram)
                } header: {
                    Text(NSLocalizedString("Graphs", comment: "Decibel Meter settings: section header for which graphs are shown"))
                } footer: {
                    Text(NSLocalizedString("The spectrum shows how loud each frequency is right now, the spectrogram shows the frequencies of the last ten seconds, with loud ones brighter.", comment: "Decibel Meter settings: footer explaining the spectrum and spectrogram"))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(role: .close) {
                    settingsSheet = false
                }
            }
        }
        .presentationDetents([.medium, .large])
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
}
