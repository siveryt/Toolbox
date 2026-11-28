//
//  Ping.swift
//  Toolbox
//
//  Created by Christian Nagel on 05.11.22.
//

import SwiftUI
import Charts
import SwiftyPing
import Haptica
import ToastSwiftUI

/// What the Ping tool does with the host.
enum PingMode: String, CaseIterable, Identifiable {
    case ping, traceroute

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ping: NSLocalizedString("Ping", comment: "Ping tool: segment that measures the round-trip time to the host")
        case .traceroute: NSLocalizedString("Traceroute", comment: "Ping tool: segment that shows the routers on the way to the host")
        }
    }
}

/// One ping of a run.
struct PingSample: Identifiable, Equatable {
    /// Counts from 1 within the run.
    let id: Int
    /// Round-trip time in milliseconds, nil if the ping got no answer.
    let time: Double?
}

/// How good a round-trip time is, for its color and label.
enum PingQuality {
    case excellent, good, fair, poor

    init(_ milliseconds: Double) {
        switch milliseconds {
        case ..<30: self = .excellent
        case ..<80: self = .good
        case ..<200: self = .fair
        default: self = .poor
        }
    }

    var color: Color {
        switch self {
        case .excellent: .green
        case .good: .mint
        case .fair: .orange
        case .poor: .red
        }
    }

    var title: String {
        switch self {
        case .excellent: NSLocalizedString("Excellent", comment: "Ping tool: rating of a very short round-trip time (under 30 ms)")
        case .good: NSLocalizedString("Good", comment: "Ping tool: rating of a short round-trip time (30 to 80 ms)")
        case .fair: NSLocalizedString("Fair", comment: "Ping tool: rating of a noticeable round-trip time (80 to 200 ms)")
        case .poor: NSLocalizedString("Poor", comment: "Ping tool: rating of a long round-trip time (over 200 ms)")
        }
    }
}

struct Ping: View {
    @AppStorage("pingHost") var host = ""
    @AppStorage("pingMode") var mode: PingMode = .ping
    /// Pings per run, 0 pings until stopped.
    @AppStorage("pingCount") var count = 10

    // Ping
    @State var samples: [PingSample] = []
    @State var pinger: SwiftyPing? = nil
    @State var isPinging = false
    /// Identifies the current ping run, so callbacks from a stopped pinger are ignored.
    @State var generation = 0

    // Traceroute
    @State var hops: [TracerouteHop] = []
    @State var hostNames: [String: String] = [:]
    @State var traceTask: Task<Void, Never>? = nil
    @State var isTracing = false
    /// The trace ran to its end (not stopped), so the footer can say whether the host was reached.
    @State var traceFinished = false

    /// The IPv4 address the host resolved to.
    @State var address: String? = nil
    @State var errorMessage: String? = nil
    @State var isPresentingToast = false
    @State private var network = NetworkMonitor()
    @FocusState private var hostFocused: Bool

    static let counts = [5, 10, 20, 50, 0]
    /// Pings shown in the chart while pinging until stopped.
    static let chartWindow = 40

    var isRunning: Bool { isPinging || isTracing }
    var trimmedHost: String { DNSLookup.host(of: host) }

    var body: some View {
        Form {
            if !network.isConnected {
                Section {
                    Label(NSLocalizedString("No Internet Connection", comment: "Domain Resolver: notice shown while the device is offline"), systemImage: "wifi.slash")
                        .foregroundStyle(.secondary)
                }
            }

            hostSection

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }

            switch mode {
            case .ping:
                if errorMessage == nil && (isPinging || !samples.isEmpty) {
                    pingSummary
                    pingStatistics
                }
            case .traceroute:
                if errorMessage == nil && (isTracing || !hops.isEmpty) {
                    routeSection
                }
            }
        }
        .animation(.default, value: mode)
        .animation(.default, value: hops)
        .animation(.default, value: errorMessage)
        .animation(.default, value: network.isConnected)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(NSLocalizedString("Mode", comment: "Ping tool: accessibility label of the picker between Ping and Traceroute"), selection: $mode) {
                    ForEach(PingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .onAppear {
            start()
        }
        .onDisappear {
            stop()
        }
        .onChange(of: mode) {
            start()
        }
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Ping")
    }

    // MARK: - Host

    private var hostSection: some View {
        Section {
            HStack {
                Text("Host")
                TextField("toolbox.sivery.de", text: $host)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.go)
                    .focused($hostFocused)
                    .onSubmit {
                        start()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }
            }
            if mode == .ping {
                Picker(NSLocalizedString("Pings", comment: "Ping tool: picker for how many pings a run sends"), selection: $count) {
                    ForEach(Self.counts, id: \.self) { count in
                        if count == 0 {
                            Text(NSLocalizedString("Until Stopped", comment: "Ping tool: option of the Pings picker that keeps pinging until the user stops")).tag(count)
                        } else {
                            Text(verbatim: count.formatted()).tag(count)
                        }
                    }
                }
            }
            Button {
                hostFocused = false
                if isRunning {
                    stop()
                } else {
                    start()
                }
            } label: {
                Label(
                    isRunning
                        ? NSLocalizedString("Stop", comment: "Ping tool: button that stops the running ping or traceroute")
                        : NSLocalizedString("Start", comment: "Ping tool: button that starts the ping or traceroute"),
                    systemImage: isRunning ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
                .contentTransition(.symbolEffect(.replace))
            }
            .tint(isRunning ? .red : .accentColor)
            .disabled(trimmedHost.isEmpty)
        } footer: {
            if let address, address != trimmedHost, errorMessage == nil {
                Text(verbatim: address)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Ping

    private var answered: [Double] { samples.compactMap(\.time) }

    private var pingSummary: some View {
        Section {
            VStack(spacing: 12) {
                VStack(spacing: 2) {
                    if let last = samples.last {
                        if let time = last.time {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(verbatim: Self.format(time))
                                    .font(.system(size: 60, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .contentTransition(.numericText(value: time))
                                Text(verbatim: "ms")
                                    .font(.title2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            qualityBadge(PingQuality(time))
                        } else {
                            Text(NSLocalizedString("Timeout", comment: "Ping tool: shown instead of a time when the host didn't answer in time"))
                                .font(.system(size: 40, weight: .semibold, design: .rounded))
                                .foregroundStyle(.red)
                            Text(NSLocalizedString("No Answer", comment: "Ping tool: shown below Timeout, and for a router on the route that didn't answer"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ProgressView()
                            .controlSize(.large)
                            .frame(height: 90)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 100)
                .animation(.snappy, value: samples.last)
                .accessibilityElement(children: .combine)

                pingChart
                    .frame(height: 120)
            }
            .padding(.vertical, 8)
        }
    }

    private func qualityBadge(_ quality: PingQuality) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(quality.color)
                .frame(width: 8, height: 8)
            Text(quality.title)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(quality.color.opacity(0.15), in: Capsule())
    }

    /// The pings in the chart: all of a run with a count, the latest ones while pinging until stopped.
    private var chartSamples: [PingSample] {
        count == 0 ? Array(samples.suffix(Self.chartWindow)) : samples
    }

    private var chartXDomain: ClosedRange<Int> {
        if count == 0 {
            let last = max(samples.last?.id ?? 0, Self.chartWindow)
            return (last - Self.chartWindow + 1)...last
        }
        return 1...max(count, samples.count)
    }

    private var chartTop: Double {
        max((chartSamples.compactMap(\.time).max() ?? 0) * 1.15, 10)
    }

    private var pingChart: some View {
        Chart {
            ForEach(chartSamples) { sample in
                if let time = sample.time {
                    BarMark(
                        x: .value("Ping", sample.id),
                        y: .value("Time", time)
                    )
                    .foregroundStyle(PingQuality(time).color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    // A lost ping fills the whole height, so it stands out.
                    BarMark(
                        x: .value("Ping", sample.id),
                        y: .value("Time", chartTop)
                    )
                    .foregroundStyle(Color.red.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            if answered.count > 1, let average = Self.average(answered) {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXScale(domain: (chartXDomain.lowerBound - 1)...(chartXDomain.upperBound + 1))
        .chartYScale(domain: 0...chartTop)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let milliseconds = value.as(Double.self) {
                        Text(verbatim: "\(Int(milliseconds)) ms")
                    }
                }
            }
        }
        .animation(.snappy, value: samples)
        .accessibilityHidden(true)
    }

    private var pingStatistics: some View {
        Section(NSLocalizedString("Statistics", comment: "Ping tool: header of the section with minimum, average and maximum time, jitter and packet loss")) {
            Grid(horizontalSpacing: 8, verticalSpacing: 16) {
                GridRow {
                    statistic(NSLocalizedString("Min", comment: "Ping tool: label of the shortest round-trip time"), answered.min().map(Self.formatWithUnit))
                    statistic(NSLocalizedString("Average", comment: "Ping tool: label of the average round-trip time"), Self.average(answered).map(Self.formatWithUnit))
                    statistic(NSLocalizedString("Max", comment: "Ping tool: label of the longest round-trip time"), answered.max().map(Self.formatWithUnit))
                }
                GridRow {
                    statistic(NSLocalizedString("Jitter", comment: "Ping tool: label of how much the round-trip time varies from ping to ping"), Self.jitter(answered).map(Self.formatWithUnit))
                    statistic(NSLocalizedString("Packet Loss", comment: "Ping tool: label of the share of pings without answer"), samples.isEmpty ? nil : (Double(samples.count - answered.count) / Double(samples.count)).formatted(.percent.precision(.fractionLength(0))))
                    statistic(NSLocalizedString("Received", comment: "Ping tool: label of how many of the sent pings got an answer, e.g. \"8/10\""), samples.isEmpty ? nil : "\(answered.count)/\(samples.count)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    private func statistic(_ title: String, _ value: String?) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: value ?? "–")
                .font(.title3.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Traceroute

    private var routeSection: some View {
        Section {
            ForEach(hops) { hop in
                hopRow(hop)
            }
            if isTracing {
                HStack(spacing: 12) {
                    ProgressView()
                        .frame(width: 30)
                    Text(String(format: NSLocalizedString("Hop %lld…", comment: "Ping tool: shown below the found routers while the traceroute waits for the next one"), (hops.last?.ttl ?? 0) + 1))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(NSLocalizedString("Route", comment: "Ping tool: header of the list of routers on the way to the host"))
        } footer: {
            if traceFinished {
                if let last = hops.last, last.isDestination {
                    Text(String.localizedStringWithFormat(NSLocalizedString("Reached the host in %lld hops.", comment: "Ping tool: below the route when the traceroute reached the host"), last.ttl))
                } else {
                    Text(String(format: NSLocalizedString("The host didn't answer within %lld hops. It may not answer pings.", comment: "Ping tool: below the route when the traceroute didn't reach the host"), Traceroute.maxHops))
                }
            } else if !isTracing {
                Text(NSLocalizedString("Touch and hold a hop to copy its address or ping it.", comment: "Ping tool: below the route after the user stopped the traceroute"))
            }
        }
    }

    private func hopRow(_ hop: TracerouteHop) -> some View {
        let name = hop.address.flatMap { hostNames[$0] }
        let color = hop.averageTime.map { PingQuality($0).color } ?? .secondary
        return Button {
            if let address = hop.address { copy(address) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if hop.isDestination {
                        Circle()
                            .fill(Color.accentColor)
                        Image(systemName: "flag.checkered")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    } else {
                        Text(verbatim: "\(hop.ttl)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(hop.address == nil ? .secondary : color)
                    }
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    if let address = hop.address {
                        Text(verbatim: name ?? address)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if name != nil {
                            Text(verbatim: address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    } else {
                        Text(NSLocalizedString("No Answer", comment: "Ping tool: shown below Timeout, and for a router on the route that didn't answer"))
                            .foregroundStyle(.secondary)
                    }
                    Text(verbatim: hop.times.map { $0.map(Self.format) ?? "*" }.joined(separator: "  ·  "))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let average = hop.averageTime {
                    Text(verbatim: Self.formatWithUnit(average))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
            }
        }
        .tint(.primary)
        .accessibilityElement(children: .combine)
        .contextMenu {
            if let address = hop.address {
                Button {
                    copy(address)
                } label: {
                    Label(NSLocalizedString("Copy Address", comment: "Ping tool: context menu item of a router on the route"), systemImage: "doc.on.doc")
                }
                if let name {
                    Button {
                        copy(name)
                    } label: {
                        Label(NSLocalizedString("Copy Host Name", comment: "Ping tool: context menu item of a router on the route"), systemImage: "doc.on.doc")
                    }
                }
                Button {
                    host = address
                    mode = .ping
                } label: {
                    Label(NSLocalizedString("Ping This Hop", comment: "Ping tool: context menu item of a router on the route, switches to Ping with its address"), systemImage: "bolt.horizontal")
                }
            }
        }
    }

    // MARK: - Running

    func start() {
        stop()
        errorMessage = nil
        address = nil
        guard !trimmedHost.isEmpty else { return }
        switch mode {
        case .ping: ping()
        case .traceroute: trace()
        }
    }

    func stop() {
        generation += 1
        pinger?.haltPinging()
        pinger = nil
        isPinging = false
        traceTask?.cancel()
        traceTask = nil
        isTracing = false
    }

    func ping() {
        samples = []
        isPinging = true
        let host = trimmedHost
        let target = count
        let current = generation

        // SwiftyPing resolves the host synchronously in its initializer, which would block the UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let newPinger = try SwiftyPing(host: host, configuration: PingConfiguration(interval: target == 0 ? 1 : 0.5, with: 2), queue: DispatchQueue.global())
                newPinger.targetCount = target == 0 ? nil : target
                let resolved = newPinger.destination.ip
                // The observer is called on the queue above, the UI is updated on the main queue.
                // (Passing .main as queue would deadlock: SwiftyPing calls it with sync from the main run loop.)
                newPinger.observer = { response in
                    DispatchQueue.main.async {
                        guard current == generation else { return }
                        let sample = PingSample(id: samples.count + 1, time: response.error == nil ? response.duration * 1000 : nil)
                        samples.append(sample)
                        // Pinging until stopped keeps only what the statistics need.
                        if samples.count > 10_000 { samples.removeFirst(samples.count - 10_000) }
                    }
                }
                newPinger.finished = { _ in
                    DispatchQueue.main.async {
                        guard current == generation else { return }
                        isPinging = false
                        pinger = nil
                        Haptic.impact(.light).generate()
                    }
                }
                DispatchQueue.main.async {
                    guard current == generation else {
                        // The user started another run or left in the meantime
                        newPinger.haltPinging()
                        return
                    }
                    address = resolved
                    pinger = newPinger
                    do {
                        try newPinger.startPinging()
                    } catch {
                        fail(with: error)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard current == generation else { return }
                    fail(with: error)
                }
            }
        }
    }

    func trace() {
        hops = []
        traceFinished = false
        isTracing = true
        let host = trimmedHost
        traceTask = Task {
            do {
                let destination = try await Task.detached(priority: .userInitiated) {
                    try Traceroute.resolve(host)
                }.value
                guard !Task.isCancelled else { return }
                address = Traceroute.string(from: destination)
                for try await hop in Traceroute.trace(to: destination) {
                    guard !Task.isCancelled else { return }
                    hops.append(hop)
                    lookUpName(of: hop.address)
                }
                guard !Task.isCancelled else { return }
                traceFinished = true
                Haptic.impact(.light).generate()
            } catch {
                guard !Task.isCancelled else { return }
                fail(with: error)
            }
            isTracing = false
        }
    }

    /// Finds the host name of a router in the background; the row shows its address until then.
    func lookUpName(of address: String?) {
        guard let address, hostNames[address] == nil else { return }
        Task {
            let name = await Task.detached(priority: .utility) {
                Traceroute.hostName(of: address)
            }.value
            if let name {
                hostNames[address] = name
            }
        }
    }

    func fail(with error: Error) {
        stop()
        switch error {
        case PingError.hostNotFound, PingError.addressLookupError, PingError.unknownHostError, TracerouteError.hostNotFound:
            errorMessage = NSLocalizedString("Couldn't find this host. Check the address and your internet connection.", comment: "Ping tool: error shown when the host name couldn't be resolved")
        case is TracerouteError:
            errorMessage = NSLocalizedString("Couldn't trace the route to this host.", comment: "Ping tool: error shown when the traceroute couldn't be started")
        default:
            errorMessage = NSLocalizedString("Couldn't ping this host.", comment: "Ping tool: error shown when pinging failed for another reason than an unknown host")
        }
    }

    func copy(_ text: String) {
        UIPasteboard.general.string = text
        Haptic.impact(.light).generate()
        withAnimation {
            isPresentingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isPresentingToast = false
            }
        }
    }

    // MARK: - Formatting

    /// Short times with one decimal, longer ones without.
    static func format(_ milliseconds: Double) -> String {
        milliseconds.formatted(.number.precision(.fractionLength(milliseconds < 10 ? 1 : 0)))
    }

    static func formatWithUnit(_ milliseconds: Double) -> String {
        format(milliseconds) + " ms"
    }

    static func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// The mean difference between consecutive round-trip times.
    static func jitter(_ values: [Double]) -> Double? {
        guard values.count > 1 else { return nil }
        let differences = zip(values, values.dropFirst()).map { abs($1 - $0) }
        return differences.reduce(0, +) / Double(differences.count)
    }
}

#Preview {
    NavigationStack {
        Ping()
    }
}
