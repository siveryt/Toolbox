//
//  Speed.swift
//  Toolbox
//
//  Created by Christian Nagel on 05.11.22.
//

import SwiftUI
import CoreLocation

struct Speed: View {
    @StateObject private var locationManager = LocationManager()

    private var isMetric: Bool {
        return Locale.current.measurementSystem == .metric
    }

    private var userSpeed: String {
        if locationManager.speed >= 0 {
            if isMetric {
                return String(format: "%.0f", locationManager.speed * 3.6) // Convert m/s to km/h
            } else {
                return String(format: "%.0f", locationManager.speed * 2.237) // Convert m/s to mph
            }
        } else {
            return "--"
        }
    }

    private var userSpeedUnit: String {
        return isMetric ? "km/h" : "mph"
    }

    private var userSpeedAccuracy: String {
        if locationManager.speedAccuracy >= 0 {
            if isMetric {
                return String(format: "%.1f km/h", locationManager.speedAccuracy * 3.6)
            } else {
                return String(format: "%.1f mph", locationManager.speedAccuracy * 2.237)
            }
        } else {
            return isMetric ? "-- km/h" : "-- mph"
        }
    }

    private var hasLocationPermission: Bool {
        return locationManager.authorizationStatus == .authorizedWhenInUse ||
               locationManager.authorizationStatus == .authorizedAlways
    }

    private var hasPreciseLocation: Bool {
        if #available(iOS 14.0, *) {
            return locationManager.accuracyAuthorization == .fullAccuracy
        } else {
            return true // iOS 13 and earlier don't have reduced accuracy
        }
    }

    // Derives a coarse GPS signal quality from the current horizontal accuracy,
    // so the user can tell *why* a speed is (or isn't) showing.
    private var gpsSignal: GPSSignal {
        if locationManager.signalIsStale { return .searching }
        let accuracy = locationManager.horizontalAccuracy
        if accuracy < 0 { return .searching }
        switch accuracy {
        case ..<10: return .strong
        case ..<25: return .good
        case ..<50: return .fair
        default: return .poor
        }
    }

    private var gpsStatusBar: some View {
        HStack(spacing: 10) {
            Spacer()
            //HStack(spacing: 6) {
                gpsSignalIndicator
                Text(gpsSignal.label)
            //}
            Spacer()
            Text("±" + userSpeedAccuracy)
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var gpsSignalIndicator: some View {
        switch gpsSignal {
        case .searching:
            // Signal bars that animate while we wait for a usable fix.
            Image(systemName: "cellularbars", variableValue: gpsSignal.fillValue)
                .foregroundStyle(gpsSignal.color)
                .symbolEffect(.variableColor.iterative)
        default:
            Image(systemName: "cellularbars", variableValue: gpsSignal.fillValue)
                .foregroundStyle(gpsSignal.color)
        }
    }

    var body: some View {
        VStack{
            if hasLocationPermission && hasPreciseLocation {
                GeometryReader { geometry in
                    VStack{
                        Spacer()
                        VStack {
                            Text(userSpeed)
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.8, design: .default))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.01)
                                .padding()
                                .frame(maxWidth: .infinity)

                            Text(userSpeedUnit)
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.1, design: .default))
                        }
                        Spacer()

                        gpsStatusBar
                            .padding(.bottom)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 20) {
                    if !hasLocationPermission {
                        VStack(spacing: 15) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)

                            Text("Location Access Required")
                                .font(.headline)

                            Text("You first have to allow Toolbox to access your location to see your speed.")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button("Open Settings") {
                                if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else if !hasPreciseLocation {
                        VStack(spacing: 15) {
                            Image(systemName: "location.north.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)

                            Text("Precise Location Required")
                                .font(.headline)

                            Text("Speed tracking requires precise location. Please enable precise location in Settings.")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button("Open Settings") {
                                if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            if #available(iOS 14.0, *) {
                                Button("Request Precise Location") {
                                    locationManager.requestTemporaryFullAccuracy()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Speed")
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true // keep screen awake while riding/driving
            locationManager.requestLocationPermission()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            locationManager.pause()
        }
    }
}

// Coarse GPS signal quality used by the on-screen status bar.
enum GPSSignal {
    case searching, poor, fair, good, strong

    // Drives how many of the four `cellularbars` fill in.
    var fillValue: Double {
        switch self {
        case .searching: return 1.0 // all bars present; the variableColor effect animates them
        case .poor: return 0.25
        case .fair: return 0.5
        case .good: return 0.75
        case .strong: return 1.0
        }
    }

    var color: Color {
        switch self {
        case .searching: return .secondary
        case .poor: return .red
        case .fair: return .orange
        case .good, .strong: return .green
        }
    }

    var label: String {
        switch self {
        case .searching: return NSLocalizedString("Acquiring GPS…", comment: "GPS signal status")
        case .poor: return NSLocalizedString("Poor GPS signal", comment: "GPS signal status")
        case .fair: return NSLocalizedString("Fair GPS signal", comment: "GPS signal status")
        case .good: return NSLocalizedString("Good GPS signal", comment: "GPS signal status")
        case .strong: return NSLocalizedString("Strong GPS signal", comment: "GPS signal status")
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var previousLocation: CLLocation?
    private var lastValidSpeedDate: Date?
    private var refreshTimer: Timer?

    // Keep showing the last valid speed this long when new fixes carry no speed,
    // so a single bad GPS reading doesn't make the display flicker to "--".
    private let speedHoldWindow: TimeInterval = 3.0
    // A fix older than this counts as "no recent fix" -> signal shown as searching.
    private let fixStaleThreshold: TimeInterval = 5.0
    // Ignore fixes worse than this horizontal accuracy (metres); they give junk speeds.
    private let maxUsableHorizontalAccuracy: CLLocationAccuracy = 100.0

    @Published var speed: Double = -1
    @Published var speedAccuracy: Double = -1
    @Published var horizontalAccuracy: CLLocationAccuracy = -1
    @Published var signalIsStale: Bool = true
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .otherNavigation
        authorizationStatus = locationManager.authorizationStatus

        if #available(iOS 14.0, *) {
            accuracyAuthorization = locationManager.accuracyAuthorization
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private var hasRecentFix: Bool {
        guard let fixDate = lastFixDate else { return false }
        return Date().timeIntervalSince(fixDate) <= fixStaleThreshold
    }

    private var lastFixDate: Date?

    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            break
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            break
        }
    }

    @available(iOS 14.0, *)
    func requestTemporaryFullAccuracy() {
        locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "SpeedTracking")
    }

    // Called when leaving the screen: stop the GPS to save battery and reset state.
    func pause() {
        stopLocationUpdates()
    }

    private func startLocationUpdates() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else { return }

        // Only start if we have precise location (iOS 14+) or on older iOS versions
        if #available(iOS 14.0, *) {
            guard locationManager.accuracyAuthorization == .fullAccuracy else {
                print("Precise location required for speed tracking")
                return
            }
        }

        locationManager.startUpdatingLocation()
        startRefreshTimer()
    }

    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        refreshTimer?.invalidate()
        refreshTimer = nil
        previousLocation = nil
        lastValidSpeedDate = nil
        lastFixDate = nil
        speed = -1
        speedAccuracy = -1
        horizontalAccuracy = -1
        signalIsStale = true
    }

    // Ticks once a second so the UI reacts even when no new fixes arrive:
    // it expires a held speed and downgrades the signal to "searching" when stale.
    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        if !hasRecentFix {
            if !signalIsStale { signalIsStale = true }
        }
        if let lastValidSpeedDate = lastValidSpeedDate,
           Date().timeIntervalSince(lastValidSpeedDate) > speedHoldWindow,
           speed >= 0 {
            speed = -1
            speedAccuracy = -1
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.process(location)
        }
    }

    private func process(_ location: CLLocation) {
        // Reject invalid or very inaccurate fixes: their speed can't be trusted.
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maxUsableHorizontalAccuracy else {
            horizontalAccuracy = location.horizontalAccuracy
            return
        }

        let now = Date()
        var resolvedSpeed: Double = -1
        var resolvedSpeedAccuracy: Double = -1

        if location.speed >= 0 {
            // Preferred: the GPS-provided (Doppler) speed — accurate when available.
            resolvedSpeed = location.speed
            resolvedSpeedAccuracy = location.speedAccuracy
        } else if let previous = previousLocation,
                  location.horizontalAccuracy <= 30,
                  previous.horizontalAccuracy <= 30 {
            // Fallback: derive speed from distance / time between two accurate fixes.
            let dt = location.timestamp.timeIntervalSince(previous.timestamp)
            if dt > 0.1 && dt < 5.0 {
                let distance = location.distance(from: previous)
                resolvedSpeed = distance < 1.0 ? 0 : distance / dt
                resolvedSpeedAccuracy = -1
            }
        }

        horizontalAccuracy = location.horizontalAccuracy
        lastFixDate = now
        signalIsStale = false

        if resolvedSpeed >= 0 {
            speed = resolvedSpeed
            speedAccuracy = resolvedSpeedAccuracy
            lastValidSpeedDate = now
        } else if let lastValidSpeedDate = lastValidSpeedDate,
                  now.timeIntervalSince(lastValidSpeedDate) > speedHoldWindow {
            // No usable speed and the hold window has elapsed: blank the display.
            speed = -1
            speedAccuracy = -1
        }
        // Otherwise keep showing the last valid speed (hold window).

        previousLocation = location
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.signalIsStale = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startLocationUpdates()
            case .denied, .restricted:
                self.stopLocationUpdates()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    @available(iOS 14.0, *)
    func locationManager(_ manager: CLLocationManager, didChangeLocationAccuracy accuracy: CLAccuracyAuthorization) {
        DispatchQueue.main.async {
            self.accuracyAuthorization = accuracy

            if accuracy == .fullAccuracy {
                self.startLocationUpdates()
            } else {
                self.stopLocationUpdates()
            }
        }
    }
}

#Preview {
    NavigationView {
        Speed()
    }
}
