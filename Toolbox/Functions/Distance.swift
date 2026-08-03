//
//  Distance.swift
//  Toolbox
//
//  Created by Christian Nagel on 12.01.26.
//

import SwiftUI
import ToastSwiftUI
import Haptica
import CoreLocation
import MapKit
import Combine

struct Distance: View {

    @StateObject private var locationManager = Location_helper()

    @State private var position: MapCameraPosition = .automatic
    @State private var startPoint: CLLocationCoordinate2D?
    @State private var startPlaceName: String?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var didCenterOnUser = false

    @State private var isPresentingToast = false
    @State private var toastMessage = ""

    // MARK: - Distance

    private var centerCoordinate: CLLocationCoordinate2D? {
        visibleRegion?.center
    }

    private var distanceMeters: Double? {
        guard let startPoint, let centerCoordinate else { return nil }
        let a = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let b = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
        return a.distance(from: b)
    }

    private func formatted(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        }
        return String(format: "%.2f km", meters / 1000)
    }

    // MARK: - Body

    private var isLocationAuthorized: Bool {
        locationManager.locationStatus == .authorizedWhenInUse
            || locationManager.locationStatus == .authorizedAlways
    }

    var body: some View {
        // The map works fine without location access — it is only used to centre on
        // the user, so we never gate the tool behind a permission prompt.
        mapContent
        .toast(isPresenting: $isPresentingToast, message: toastMessage, icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(NSLocalizedString("Distance", comment: ""))
        .toolbar {
            if let distanceMeters {
                ToolbarItem(placement: .principal) {
                    Button {
                        copyDistance(distanceMeters)
                    } label: {
                        HStack(spacing: 6) {
                            Text(formatted(distanceMeters))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        .font(.headline)
                    }
                    .buttonStyle(.plain)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    recenterOnUser()
                } label: {
                    Image(systemName: "location.fill")
                }
                .disabled(locationManager.lastLocation == nil)
                .accessibilityLabel(Text(NSLocalizedString("Center on my location", comment: "")))
            }
        }
    }

    // MARK: - Map

    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $position) {
                if isLocationAuthorized {
                    UserAnnotation()
                }

                if let startPoint {
                    Marker(startPlaceName ?? NSLocalizedString("Start", comment: ""), monogram: Text("A"), coordinate: startPoint)
                        .tint(.red)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            // Tapping sets the start point at the current map center (where the pin is).
            .onTapGesture {
                if let centerCoordinate {
                    setStart(centerCoordinate)
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                visibleRegion = context.region
            }
            .ignoresSafeArea()
            .overlay { measurementOverlay(proxy: proxy) }
            .overlay(alignment: .bottom) { startHint }
            // Center on the user the first time we get a fix.
            .onReceive(locationManager.$lastLocation.compactMap { $0 }) { location in
                guard !didCenterOnUser else { return }
                didCenterOnUser = true
                withAnimation {
                    position = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
        }
    }

    /// Draws the connecting line and the center pin in screen space, so the center
    /// end never lags behind the map and the pin tip stays exactly on the center.
    private func measurementOverlay(proxy: MapProxy) -> some View {
        GeometryReader { geo in
            let fallback = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let centerPt = visibleRegion.flatMap { proxy.convert($0.center, to: .local) } ?? fallback
            ZStack {
                if let startPoint,
                   let startPt = proxy.convert(startPoint, to: .local) {
                    Path { path in
                        path.move(to: startPt)
                        path.addLine(to: centerPt)
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 6]))
                }

                centerPin
                    .position(x: centerPt.x, y: centerPt.y - markerTipOffset) // tip rests on the exact center
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Vertical distance from the native marker view's frame centre to its balloon
    /// tip, so `.position` can land the tip exactly on the measured centre point.
    private let markerTipOffset: CGFloat = 20

    /// The moving second point: the real native `MKMarkerAnnotationView` (the exact
    /// view MapKit renders markers with), shown as a fixed screen overlay so it never
    /// lags behind the map center.
    private var centerPin: some View {
        NativeMarker(tint: UIColor(Color.accentColor), glyphText: "B")
            .frame(width: 40, height: 50)
    }

    @ViewBuilder
    private var startHint: some View {
        if startPoint == nil {
            Label(NSLocalizedString("Move the map and tap to set the start point", comment: ""), systemImage: "hand.tap.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 28)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Actions

    private func setStart(_ coordinate: CLLocationCoordinate2D) {
        withAnimation {
            startPoint = coordinate
        }
        Haptic.impact(.medium).generate()
        reverseGeocode(coordinate)
    }

    private func recenterOnUser() {
        guard let coordinate = locationManager.lastLocation?.coordinate else { return }
        let span = visibleRegion?.span ?? MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        withAnimation {
            position = .region(MKCoordinateRegion(center: coordinate, span: span))
        }
        Haptic.impact(.light).generate()
    }

    private func copyDistance(_ meters: Double) {
        UIPasteboard.general.string = formatted(meters)
        presentToast(message: NSLocalizedString("Copied", comment: "Copy toast"))
        Haptic.impact(.light).generate()
    }

    private func reverseGeocode(_ target: CLLocationCoordinate2D) {
        startPlaceName = nil
        let location = CLLocation(latitude: target.latitude, longitude: target.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let name = placemark.name
                ?? [placemark.thoroughfare, placemark.locality].compactMap { $0 }.joined(separator: ", ")
            DispatchQueue.main.async {
                startPlaceName = name.isEmpty ? nil : name
            }
        }
    }

    private func presentToast(message: String) {
        toastMessage = message
        withAnimation {
            isPresentingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isPresentingToast = false
            }
        }
    }
}

/// Wraps `MKMarkerAnnotationView` — the exact UIKit view MapKit uses to render a
/// marker — so the genuine native Apple balloon can be placed as a plain overlay,
/// with no map underneath and therefore no lag.
private struct NativeMarker: UIViewRepresentable {
    var tint: UIColor
    var glyphText: String

    func makeUIView(context: Context) -> MKMarkerAnnotationView {
        let marker = MKMarkerAnnotationView(annotation: MKPointAnnotation(), reuseIdentifier: nil)
        marker.markerTintColor = tint
        marker.glyphText = glyphText
        marker.animatesWhenAdded = false
        marker.isUserInteractionEnabled = false
        marker.backgroundColor = .clear
        return marker
    }

    func updateUIView(_ uiView: MKMarkerAnnotationView, context: Context) {
        uiView.markerTintColor = tint
        uiView.glyphText = glyphText
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MKMarkerAnnotationView, context: Context) -> CGSize? {
        CGSize(width: 40, height: 50)
    }
}

struct Distance_Previews: PreviewProvider {
    static var previews: some View {
        Distance()
    }
}
