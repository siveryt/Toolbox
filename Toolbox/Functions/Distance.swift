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

/// A point the user placed on the map. The distance runs through all of them in order.
private struct Waypoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var name: String?
}

struct Distance: View {

    @StateObject private var locationManager = Location_helper()

    @State private var position: MapCameraPosition = .automatic
    @State private var points: [Waypoint] = []
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var didCenterOnUser = false

    @State private var isPresentingToast = false
    @State private var toastMessage = ""

    // MARK: - Distance

    private var centerCoordinate: CLLocationCoordinate2D? {
        visibleRegion?.center
    }

    /// Length of the path through all points and on to the map center.
    private var distanceMeters: Double? {
        guard !points.isEmpty, let centerCoordinate else { return nil }
        let path = points.map(\.coordinate) + [centerCoordinate]
        return zip(path, path.dropFirst()).reduce(0) { total, segment in
            let a = CLLocation(latitude: segment.0.latitude, longitude: segment.0.longitude)
            let b = CLLocation(latitude: segment.1.latitude, longitude: segment.1.longitude)
            return total + a.distance(from: b)
        }
    }

    private func formatted(_ meters: Double) -> String {
        // Follow the user's regional setting: metric shows m/km, imperial shows ft/mi.
        // Formatted with the current locale, so German shows "1,23 km".
        if Locale.current.measurementSystem == .metric {
            if meters < 1000 {
                return format(meters, .meters, fractionDigits: 0)
            }
            return format(meters / 1000, .kilometers, fractionDigits: 2)
        } else {
            let feet = meters * 3.280839895
            if feet < 1000 {
                return format(feet, .feet, fractionDigits: 0)
            }
            return format(meters / 1609.344, .miles, fractionDigits: 2)
        }
    }

    private func format(_ value: Double, _ unit: UnitLength, fractionDigits: Int) -> String {
        Measurement(value: value, unit: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(fractionDigits))))
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
        .navigationTitle(NSLocalizedString("Distance", comment: "Navigation title of the Distance tool"))
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
                    resetPoints()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .disabled(points.isEmpty)
                .accessibilityLabel(Text(NSLocalizedString("Remove all points", comment: "Distance tool: accessibility label of the reset button")))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    recenterOnUser()
                } label: {
                    Image(systemName: "location.fill")
                }
                .disabled(locationManager.lastLocation == nil)
                .accessibilityLabel(Text(NSLocalizedString("Center on my location", comment: "Distance tool: accessibility label of the location button")))
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

                if points.count > 1 {
                    MapPolyline(coordinates: points.map(\.coordinate))
                        // Map content ignores the app tint, so name the accent color explicitly.
                        .stroke(Color(.accent), lineWidth: 3)
                }

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    Marker(point.name ?? markerFallbackTitle(index), monogram: Text(String(index + 1)), coordinate: point.coordinate)
                        .tint(.red)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            // Tapping adds a point at the current map center (where the pin is).
            .onTapGesture {
                if let centerCoordinate {
                    addPoint(centerCoordinate)
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
                if let lastPoint = points.last,
                   let lastPt = proxy.convert(lastPoint.coordinate, to: .local) {
                    Path { path in
                        path.move(to: lastPt)
                        path.addLine(to: centerPt)
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 6]))
                }

                centerPin
                    .position(x: centerPt.x, y: centerPt.y - markerTipOffset)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Vertical distance from the native marker view's frame centre to its balloon
    /// tip, so `.position` can land the tip exactly on the measured centre point.
    private let markerTipOffset: CGFloat = 20

    /// The moving next point, pinned to the map centre and numbered like the point it would become.
    private var centerPin: some View {
        NativeMarker(tint: UIColor(Color.accentColor), glyphText: String(points.count + 1))
            .frame(width: 40, height: 50)
    }

    private func markerFallbackTitle(_ index: Int) -> String {
        if index == 0 {
            return NSLocalizedString("Start", comment: "Distance tool: map marker of the start point when its place name is unknown")
        }
        return String(format: NSLocalizedString("Point %lld", comment: "Distance tool: map marker of a later point when its place name is unknown, %lld is its number"), index + 1)
    }

    @ViewBuilder
    private var startHint: some View {
        if points.isEmpty {
            Label(NSLocalizedString("Move the map and tap to set the start point", comment: "Distance tool: hint before a start point is set"), systemImage: "hand.tap.fill")
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

    private func addPoint(_ coordinate: CLLocationCoordinate2D) {
        let point = Waypoint(coordinate: coordinate)
        withAnimation {
            points.append(point)
        }
        Haptic.impact(.medium).generate()
        reverseGeocode(point)
    }

    private func resetPoints() {
        withAnimation {
            points.removeAll()
        }
        Haptic.impact(.rigid).generate()
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

    private func reverseGeocode(_ point: Waypoint) {
        let location = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let name = placemark.name
                ?? [placemark.thoroughfare, placemark.locality].compactMap { $0 }.joined(separator: ", ")
            DispatchQueue.main.async {
                // The points may have been reset while the lookup ran; drop stale results.
                guard let index = points.firstIndex(where: { $0.id == point.id }) else { return }
                points[index].name = name.isEmpty ? nil : name
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
