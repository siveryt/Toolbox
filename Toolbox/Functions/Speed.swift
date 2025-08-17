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

                        Text("±" + userSpeedAccuracy)
                            .foregroundStyle(.secondary)
                    }
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
            locationManager.requestLocationPermission()
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var speed: Double = -1
    @Published var speedAccuracy: Double = -1
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0 // Update every meter
        authorizationStatus = locationManager.authorizationStatus

        if #available(iOS 14.0, *) {
            accuracyAuthorization = locationManager.accuracyAuthorization
        }
    }

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
    }

    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            // Only update speed if we have valid speed data
            if location.speed >= 0 {
                self.speed = location.speed // Speed in m/s
                self.speedAccuracy = location.speedAccuracy
            } else {
                self.speed = -1
                self.speedAccuracy = -1
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.speed = -1
            self.speedAccuracy = -1
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
                self.speed = -1
                self.speedAccuracy = -1
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
                self.speed = -1
                self.speedAccuracy = -1
            }
        }
    }
}

#Preview {
    NavigationView {
        Speed()
    }
}
