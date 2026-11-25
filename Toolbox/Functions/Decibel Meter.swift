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
    /// A new spectrum every `hopSize` samples, about 47 a second at 48 kHz.
    static let hopSize = 1024
    static let bandCount = 128
    static let minFrequency = 20.0
    /// Seconds shown by the level history and the spectrogram.
    static let historyDuration = 10.0
    /// The level and its history are updated this often.
    static let tickInterval = 0.1
    static let historyLength = Int(historyDuration / tickInterval)
    /// What 0 dBFS (the loudest the microphone can record) is shown as.
    static let displayOffset: Float = 100
    /// The spectrum and spectrogram show band levels in this range (dBFS).
    static let spectrumRange: ClosedRange<Float> = -100 ... -20

    struct LevelSample: Identifiable {
        let id: Int
        let level: Float
    }

    /// The band levels of one FFT and when its last sample was recorded (`CACurrentMediaTime`).
    private struct Spectrum {
        let id: Int
        let time: Double
        let bands: [Float]
        /// Each band's position in `spectrumRange`, 0...255, for the spectrogram's colors.
        let shades: [UInt8]
    }

    var weighting: DecibelWeighting = .a {
        didSet { if weighting != oldValue { resetStatistics() } }
    }
    var timeWeighting: DecibelTimeWeighting = .fast {
        didSet { if timeWeighting != oldValue { resetStatistics() } }
    }

    /// The current level as shown, about 0...100.
    private(set) var level: Float = 0
    /// The last ten seconds of levels, oldest first.
    private(set) var history: [LevelSample] = []
    private(set) var sampleCount = 0
    /// The quietest and loudest level since the start or the last reset, as shown.
    private(set) var minimum: Float?
    private(set) var maximum: Float?
    /// The equivalent continuous level (Leq): the average sound energy since the start or the last reset, as a level.
    private(set) var equivalentLevel: Float?
    /// The center frequency of each band.
    private(set) var bandFrequencies: [Double] = DecibelAnalyzer.bandCenters(maxFrequency: 20000)
    /// The highest frequency shown, limited by the sample rate.
    private(set) var maxFrequency = 20000.0
    private(set) var isRunning = false

    // Main thread
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var timer: Timer?
    /// Mean square of the input per weighting and time weighting, exponentially averaged.
    @ObservationIgnored private var smoothed: [DecibelWeighting: [DecibelTimeWeighting: Float]] = [:]
    @ObservationIgnored private var lowestLevel = Float.infinity
    @ObservationIgnored private var highestLevel = -Float.infinity
    /// Mean square times seconds, and the seconds measured, for the Leq.
    @ObservationIgnored private var energy = 0.0
    @ObservationIgnored private var energyDuration = 0.0
    /// The spectra of the last ten seconds and a bit, oldest first.
    @ObservationIgnored private var spectra: [Spectrum] = []
    @ObservationIgnored private var nextSpectrumID = 0
    @ObservationIgnored private var hopDuration = Double(DecibelAnalyzer.hopSize) / 48000
    /// The number of spectra in the spectrogram's ten seconds.
    @ObservationIgnored private var spectrogramColumns = Int(DecibelAnalyzer.historyDuration * 48000) / DecibelAnalyzer.hopSize
    /// The spectra arrive in bursts with each audio buffer; showing them this much later lets them move evenly.
    @ObservationIgnored private var displayDelay = 0.15
    @ObservationIgnored private var spectrogramCache: (id: Int, image: CGImage)?
    /// The spectrogram's pixels, kept between frames so only new columns have to be drawn.
    @ObservationIgnored private var spectrogramPixels: [UInt32] = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    // Tap thread (set up before the tap is installed)
    @ObservationIgnored private var samples: [Float] = []
    @ObservationIgnored private var samplesSinceSpectrum = 0
    @ObservationIgnored private var window: [Float] = []
    @ObservationIgnored private var windowed: [Float] = []
    @ObservationIgnored private var power: [Float] = []
    @ObservationIgnored private var realp: [Float] = []
    @ObservationIgnored private var imagp: [Float] = []
    @ObservationIgnored private var fftSetup: FFTSetup?
    /// Squared gain of each FFT bin per weighting.
    @ObservationIgnored private var binGains: [DecibelWeighting: [Float]] = [:]
    /// How much of the latest spectrum's energy each weighting lets through.
    @ObservationIgnored private var weightingRatios: [DecibelWeighting: Float] = [:]
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
            // iOS may deliver larger buffers than asked for; they are analyzed in hops either way.
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(Self.hopSize), format: format) { [weak self] buffer, _ in
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
        if isRunning { isRunning = false }
        timer?.invalidate()
        timer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func resetStatistics() {
        lowestLevel = .infinity
        highestLevel = -.infinity
        energy = 0
        energyDuration = 0
        minimum = nil
        maximum = nil
        equivalentLevel = nil
    }

    /// Clears the measurements and sets up the FFT for `sampleRate`.
    private func prepare(sampleRate: Double) {
        let n = Self.fftSize
        let half = n / 2
        smoothed = [:]
        history = []
        spectra = []
        spectrogramCache = nil
        resetStatistics()
        hopDuration = Double(Self.hopSize) / sampleRate
        spectrogramColumns = Int(Self.historyDuration / hopDuration)

        samples = Array(repeating: 0, count: n)
        samplesSinceSpectrum = 0
        weightingRatios = [:]
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

    /// Converts a mean square (1 is full scale) into the level shown.
    private static func displayLevel(meanSquare: Double) -> Float {
        max(0, Float(10 * log10(max(meanSquare, 1e-20))) + displayOffset)
    }

    /// Runs on the tap's thread.
    private func analyze(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        var meanSquare: Float = 0
        vDSP_measqv(data, 1, &meanSquare, vDSP_Length(count))

        // An FFT over the newest `fftSize` samples after every `hopSize` samples.
        var newSpectra: [(bands: [Float], shades: [UInt8], samplesAfter: Int)] = []
        var position = 0
        while position < count {
            let chunk = min(count - position, Self.hopSize - samplesSinceSpectrum)
            samples.removeFirst(chunk)
            samples.append(contentsOf: UnsafeBufferPointer(start: data + position, count: chunk))
            position += chunk
            samplesSinceSpectrum += chunk
            if samplesSinceSpectrum == Self.hopSize {
                samplesSinceSpectrum = 0
                if let (bands, shades) = transform() {
                    newSpectra.append((bands, shades, count - position))
                }
            }
        }

        // The weightings scale the level by how much they let through of the current spectrum.
        var weightedMeanSquares: [DecibelWeighting: Float] = [:]
        for weighting in DecibelWeighting.allCases {
            weightedMeanSquares[weighting] = meanSquare * (weightingRatios[weighting] ?? 1)
        }

        let duration = Double(count) / buffer.format.sampleRate
        let sampleRate = buffer.format.sampleRate
        DispatchQueue.main.async { [weak self] in
            self?.receive(meanSquares: weightedMeanSquares, spectra: newSpectra, duration: duration, sampleRate: sampleRate)
        }
    }

    /// Runs on the tap's thread: the FFT of `samples`, as band levels in dBFS and their spectrogram shades.
    private func transform() -> ([Float], [UInt8])? {
        guard let fftSetup else { return nil }
        let n = Self.fftSize
        let half = n / 2
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

        let total = vDSP.sum(power)
        if total > 0 {
            for weighting in DecibelWeighting.allCases {
                guard weighting != .z, let gains = binGains[weighting] else { continue }
                weightingRatios[weighting] = vDSP.dot(power, gains) / total
            }
        }

        // vDSP's FFT is twice the DFT, and the Hann window halves the amplitude: a full-scale sine reaches (n / 2)².
        let fullScale = Float(half * half)
        let range = Self.spectrumRange
        let bands = bandBins.map { bins in
            10 * log10(max(power[bins].max() ?? 0, 1e-20) / fullScale)
        }
        let shades = bands.map { level in
            UInt8(min(max((level - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1) * 255)
        }
        return (bands, shades)
    }

    private func receive(meanSquares: [DecibelWeighting: Float], spectra newSpectra: [(bands: [Float], shades: [UInt8], samplesAfter: Int)], duration: Double, sampleRate: Double) {
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

        if let current = smoothed[weighting]?[timeWeighting] {
            let shown = Self.displayLevel(meanSquare: Double(current))
            lowestLevel = min(lowestLevel, shown)
            highestLevel = max(highestLevel, shown)
        }
        energy += Double(meanSquares[weighting] ?? 0) * duration
        energyDuration += duration

        let now = CACurrentMediaTime()
        // Show each buffer's spectra while the next buffer is recorded.
        displayDelay = max(duration, hopDuration) + 0.05
        for spectrum in newSpectra {
            spectra.append(Spectrum(id: nextSpectrumID, time: now - Double(spectrum.samplesAfter) / sampleRate, bands: spectrum.bands, shades: spectrum.shades))
            nextSpectrumID += 1
        }
        let capacity = spectrogramColumns + Int(displayDelay / hopDuration) + 4
        if spectra.count > capacity {
            spectra.removeFirst(spectra.count - capacity)
        }
    }

    /// Updates the level, its history and the statistics, ten times a second.
    private func tick() {
        guard let meanSquare = smoothed[weighting]?[timeWeighting] else { return }
        level = Self.displayLevel(meanSquare: Double(meanSquare))
        history.append(LevelSample(id: sampleCount, level: level))
        sampleCount += 1
        if history.count > Self.historyLength {
            history.removeFirst(history.count - Self.historyLength)
        }
        if lowestLevel.isFinite { minimum = lowestLevel }
        if highestLevel.isFinite { maximum = highestLevel }
        if energyDuration > 0 { equivalentLevel = Self.displayLevel(meanSquare: energy / energyDuration) }
    }

    /// The moment the spectrum and spectrogram show now.
    var displayTime: Double {
        CACurrentMediaTime() - displayDelay
    }

    /// The band levels (dBFS) at `time`, between the two spectra around it.
    func spectrum(at time: Double) -> [Float]? {
        guard let index = spectra.lastIndex(where: { $0.time <= time }) else { return nil }
        let earlier = spectra[index]
        guard index + 1 < spectra.count else { return earlier.bands }
        let later = spectra[index + 1]
        let t = Float((time - earlier.time) / (later.time - earlier.time))
        return zip(earlier.bands, later.bands).map { $0 + ($1 - $0) * t }
    }

    /// The spectrogram up to the last spectrum before `time`, one column per spectrum, with the newest on the right;
    /// `offset` is how far (in columns, 0...1) it has moved on since that spectrum.
    func spectrogram(at time: Double) -> (image: CGImage, offset: Double)? {
        guard let index = spectra.lastIndex(where: { $0.time <= time }) else { return nil }
        let latest = spectra[index]
        let offset = min(max((time - latest.time) / hopDuration, 0), 1)
        if let cache = spectrogramCache, cache.id == latest.id {
            return (cache.image, offset)
        }
        let width = spectrogramColumns
        let height = Self.bandCount
        if spectrogramPixels.count != width * height {
            spectrogramPixels = Array(repeating: 0, count: width * height)
            spectrogramCache = nil
        }
        // Move the columns that are already drawn to the left and draw only the new ones.
        let newColumns = min(latest.id - (spectrogramCache?.id ?? latest.id - width), width)
        spectrogramPixels.withUnsafeMutableBufferPointer { pixels in
            guard let base = pixels.baseAddress else { return }
            for row in 0..<height {
                let start = base + row * width
                if newColumns < width {
                    start.update(from: start + newColumns, count: width - newColumns)
                }
                (start + width - newColumns).update(repeating: 0, count: newColumns)
            }
            for column in 0..<newColumns {
                let spectrumIndex = index - (newColumns - 1 - column)
                guard spectrumIndex >= 0 else { continue }
                let x = width - newColumns + column
                for (band, shade) in spectra[spectrumIndex].shades.enumerated() {
                    base[(height - 1 - band) * width + x] = Self.colorTable[Int(shade)]
                }
            }
        }
        let data = spectrogramPixels.withUnsafeBytes { Data($0) }
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { return nil }
        spectrogramCache = (latest.id, image)
        return (image, offset)
    }

    /// The premultiplied RGBA color (R in the lowest byte) of each shade: quiet is transparent, then purple, red, orange
    /// and pale yellow for the loudest.
    private static let colorTable: [UInt32] = (0...255).map { shade in
        let value = Float(shade) / 255
        let stops: [(position: Float, r: Float, g: Float, b: Float)] = [
            (0, 0.25, 0.05, 0.55),
            (0.45, 0.85, 0.15, 0.35),
            (0.75, 1, 0.55, 0.1),
            (1, 1, 0.95, 0.6),
        ]
        let alpha = min(value * 2, 1)
        let upper = stops.firstIndex(where: { $0.position >= value }) ?? stops.count - 1
        let a = stops[max(upper - 1, 0)], b = stops[max(upper, 1)]
        let t = min(max((value - a.position) / (b.position - a.position), 0), 1)
        let red = UInt32((a.r + (b.r - a.r) * t) * alpha * 255)
        let green = UInt32((a.g + (b.g - a.g) * t) * alpha * 255)
        let blue = UInt32((a.b + (b.b - a.b) * t) * alpha * 255)
        return red | green << 8 | blue << 16 | UInt32(alpha * 255) << 24
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
    @AppStorage("decibelShowStatistics") private var showStatistics = true

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
            let numberHeight = geometry.size.height - (graphHeight + 16) * CGFloat(graphCount) - (showStatistics ? 70 : 0)
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
                    if showStatistics {
                        statistics.padding(.top, 12)
                    }
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

    /// How loud each frequency is right now, redrawn every frame.
    private var spectrumGraph: some View {
        TimelineView(.animation(paused: !analyzer.isRunning)) { timeline in
            Canvas { context, size in
                _ = timeline.date
                let range = DecibelAnalyzer.spectrumRange
                let labelHeight: CGFloat = 18
                let plotHeight = size.height - labelHeight
                let logMin = log(DecibelAnalyzer.minFrequency)
                let logRange = log(analyzer.maxFrequency) - logMin
                func x(_ frequency: Double) -> CGFloat {
                    size.width * (log(frequency) - logMin) / logRange
                }

                for frequency in Self.labeledFrequencies {
                    var line = Path()
                    line.move(to: CGPoint(x: x(frequency), y: 0))
                    line.addLine(to: CGPoint(x: x(frequency), y: plotHeight))
                    context.stroke(line, with: .color(.secondary.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    context.draw(
                        Text(verbatim: Self.frequencyLabel(frequency)).font(.caption2).foregroundStyle(.secondary),
                        at: CGPoint(x: min(max(x(frequency), 22), size.width - 22), y: plotHeight + labelHeight / 2)
                    )
                }

                guard let bands = analyzer.spectrum(at: analyzer.displayTime) else { return }
                var line = Path()
                for (band, level) in bands.enumerated() {
                    let value = CGFloat((min(max(level, range.lowerBound), range.upperBound) - range.lowerBound) / (range.upperBound - range.lowerBound))
                    let point = CGPoint(x: x(analyzer.bandFrequencies[band]), y: plotHeight * (1 - value))
                    band == 0 ? line.move(to: point) : line.addLine(to: point)
                }
                var area = line
                area.addLine(to: CGPoint(x: x(analyzer.bandFrequencies[bands.count - 1]), y: plotHeight))
                area.addLine(to: CGPoint(x: x(analyzer.bandFrequencies[0]), y: plotHeight))
                area.closeSubpath()
                context.fill(area, with: .linearGradient(
                    Gradient(colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.1)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: plotHeight)
                ))
                context.stroke(line, with: .color(.accentColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }

    /// The spectrum of the last ten seconds, the newest on the right, moving on every frame.
    private var spectrogramGraph: some View {
        TimelineView(.animation(paused: !analyzer.isRunning)) { timeline in
            Canvas { context, size in
                _ = timeline.date
                context.clip(to: Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8))
                guard let (image, offset) = analyzer.spectrogram(at: analyzer.displayTime) else { return }
                let columns = CGFloat(image.width)
                // One column more than fits, so the left edge stays filled while the image moves left.
                let columnWidth = size.width / (columns - 1)
                let rect = CGRect(x: size.width - columns * columnWidth - offset * columnWidth, y: 0, width: columns * columnWidth, height: size.height)
                context.draw(Image(decorative: image, scale: 1).interpolation(.medium), in: rect)
            }
        }
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            GeometryReader { geometry in
                ForEach(Self.labeledFrequencies, id: \.self) { frequency in
                    let position = log(frequency / DecibelAnalyzer.minFrequency) / log(analyzer.maxFrequency / DecibelAnalyzer.minFrequency)
                    Text(verbatim: Self.frequencyLabel(frequency))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .background(.background.opacity(0.6), in: Capsule())
                        .position(x: geometry.size.width - 24, y: geometry.size.height * (1 - position))
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Min, Leq and Max since the start or the last reset.
    private var statistics: some View {
        HStack(spacing: 24) {
            statistic(NSLocalizedString("Min", comment: "Decibel Meter: label of the quietest level since the start"), analyzer.minimum)
            statistic("Leq", analyzer.equivalentLevel)
            statistic(NSLocalizedString("Max", comment: "Decibel Meter: label of the loudest level since the start"), analyzer.maximum)
            Button {
                analyzer.resetStatistics()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text(NSLocalizedString("Reset Statistics", comment: "Decibel Meter: accessibility label of the button that resets Min, Max and Leq")))
        }
    }

    private func statistic(_ title: String, _ value: Float?) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: value?.formatted(.number.precision(.fractionLength(1))) ?? "–")
                .font(.title3)
                .monospacedDigit()
        }
        .frame(minWidth: 56)
        .accessibilityElement(children: .combine)
    }

    private static let labeledFrequencies: [Double] = [100, 1000, 10000]

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
                    Toggle(NSLocalizedString("Min, Max and Leq", comment: "Decibel Meter settings: toggle for the statistics below the level (Leq is the technical term for the average level)"), isOn: $showStatistics)
                } header: {
                    Text(NSLocalizedString("Graphs", comment: "Decibel Meter settings: section header for which graphs are shown"))
                } footer: {
                    Text(NSLocalizedString("The spectrum shows how loud each frequency is right now, the spectrogram shows the frequencies of the last ten seconds, with loud ones brighter. Min and Max are the quietest and loudest level, Leq is the average sound energy, all since you opened the meter or reset them.", comment: "Decibel Meter settings: footer explaining the spectrum, the spectrogram and the statistics"))
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
