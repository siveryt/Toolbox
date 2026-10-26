//
//  FullscreenCamera.swift
//  Toolbox
//
//  Created by Christian Nagel on 26.10.26.
//

import SwiftUI
import AVFoundation

/// Shows the camera's complete picture full screen, also on a connected display (AirPlay, monitor), e.g. as a document camera for presentations.
/// The picture on that display can be frozen or muted (black) while the phone keeps showing the live camera.
struct FullscreenCamera: View {
    @State var feed = CameraFeed()
    @State var cameraState: CameraState = .starting
    @State var isFrozen = false
    @State var isMuted = false
    @State var controlsHidden = false
    /// Whether a connected display currently shows the picture.
    @State var externalDisplayAvailable = false
    @State var zoomAtGestureStart: CGFloat?

    enum CameraState {
        case starting, running, accessDenied, failed
        /// The simulator has no camera, so it shows a photo of a book (also for the App Store screenshots).
        case demo
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // The phone shows the live camera while a display shows the picture, otherwise it is the picture the audience sees.
            CameraPicture(feed: feed, isDemo: cameraState == .demo, followsFreeze: !externalDisplayAvailable)
                .overlay {
                    if isMuted && !externalDisplayAvailable { Color.black }
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation { controlsHidden.toggle() }
                }
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let start = zoomAtGestureStart ?? feed.zoom
                            zoomAtGestureStart = start
                            feed.setZoom(start * value.magnification)
                        }
                        .onEnded { _ in zoomAtGestureStart = nil }
                )

            switch cameraState {
            case .accessDenied:
                ContentUnavailableView {
                    Label(NSLocalizedString("Camera Access Needed", comment: "Fullscreen Camera: title when camera access is denied"), systemImage: "camera")
                } description: {
                    Text(NSLocalizedString("Allow camera access to show the camera full screen and on a connected display.", comment: "Fullscreen Camera: message when camera access is denied"))
                } actions: {
                    Button(NSLocalizedString("Open Settings", comment: "Fullscreen Camera: button that opens the app's settings to allow camera access")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .foregroundStyle(.white)
            case .failed:
                ContentUnavailableView(
                    NSLocalizedString("Camera Unavailable", comment: "Fullscreen Camera: title when the camera can't be started"),
                    systemImage: "video.slash",
                    description: Text(NSLocalizedString("The camera couldn't be started. It may be in use by another app.", comment: "Fullscreen Camera: message when the camera can't be started"))
                )
                .foregroundStyle(.white)
            case .starting, .running, .demo:
                if !controlsHidden {
                    // Keeps the white title and labels (and the glass) readable on a bright picture, e.g. a sheet of paper.
                    // Only up to these heights, so the stack never gets taller than a phone in landscape.
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(maxHeight: 220)
                        Spacer(minLength: 0)
                        LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                            .frame(maxHeight: 280)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)

                    controls
                        .environment(\.colorScheme, .dark)
                        .transition(.opacity)
                }
            }
        }
        .navigationTitle(NSLocalizedString("Fullscreen Camera", comment: "Menu item"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(controlsHidden ? .hidden : .automatic, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .statusBarHidden(controlsHidden)
        .persistentSystemOverlays(controlsHidden ? .hidden : .automatic)
        .externalDisplayPicture(isAvailable: $externalDisplayAvailable) {
            ZStack {
                Color.black
                if !isMuted {
                    CameraPicture(feed: feed, isDemo: cameraState == .demo, followsFreeze: true)
                }
            }
            .ignoresSafeArea()
        }
        .task {
            #if targetEnvironment(simulator)
            cameraState = .demo
            feed.useDemoLenses()
            #else
            switch await feed.start() {
            case .running: cameraState = .running
            case .accessDenied: cameraState = .accessDenied
            case .failed: cameraState = .failed
            }
            #endif
        }
        .onChange(of: isFrozen) { _, frozen in
            feed.setFrozen(frozen)
        }
        // Keep the screen on, so it doesn't dim or lock during the presentation.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            feed.stop()
        }
    }

    private var controls: some View {
        VStack {
            Text(statusText)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect()
                .padding(.top, 8)
                .padding(.horizontal)

            Spacer()

            if feed.lensZooms.count > 1 {
                lensButtons
                    .padding(.bottom, 12)
            }

            GlassEffectContainer {
                HStack(spacing: 24) {
                    controlButton(
                        NSLocalizedString("Freeze", comment: "Fullscreen Camera: button that holds the current picture on the display"),
                        systemImage: "snowflake",
                        isOn: isFrozen
                    ) {
                        isFrozen.toggle()
                    }
                    controlButton(
                        NSLocalizedString("Mute", comment: "Fullscreen Camera: button that turns the display black, like the mute button of a projector"),
                        systemImage: "rectangle.slash",
                        isOn: isMuted
                    ) {
                        isMuted.toggle()
                    }
                    controlButton(
                        NSLocalizedString("Switch", comment: "Fullscreen Camera: button that switches between the back and the front camera"),
                        systemImage: "arrow.triangle.2.circlepath.camera",
                        isOn: false
                    ) {
                        feed.switchCamera()
                    }
                    .disabled(cameraState == .demo)
                }
            }
            .padding(.bottom, 24)
        }
    }

    /// One button per lens, like in the Camera app; the selected one shows the current zoom.
    private var lensButtons: some View {
        let selectedLens = feed.lensZooms.last { $0 <= feed.zoom + 0.05 } ?? feed.lensZooms.first
        return HStack(spacing: 2) {
            ForEach(feed.lensZooms, id: \.self) { lens in
                let isSelected = lens == selectedLens
                Button {
                    feed.setZoom(lens, animated: true)
                } label: {
                    Text(verbatim: isSelected ? Self.zoomText(feed.zoom) + "×" : Self.zoomText(lens))
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? .yellow : .white)
                        .frame(minWidth: 38, minHeight: 38)
                        .background(.black.opacity(isSelected ? 0.45 : 0.2), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("Zoom", comment: "Fullscreen Camera: accessibility label of the lens buttons (0.5×, 1×, 2×, …)"))
                .accessibilityValue(Self.zoomText(lens) + "×")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect()
        .sensoryFeedback(.selection, trigger: selectedLens)
    }

    private static func zoomText(_ zoom: CGFloat) -> String {
        Double(zoom).formatted(.number.precision(.fractionLength(0...1)))
    }

    private func controlButton(_ title: String, systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Group {
                if isOn {
                    Button(action: action) { Image(systemName: systemImage).frame(width: 36, height: 36) }
                        .buttonStyle(.glassProminent)
                } else {
                    Button(action: action) { Image(systemName: systemImage).frame(width: 36, height: 36) }
                        .buttonStyle(.glass)
                }
            }
            .font(.title2)
            .buttonBorderShape(.circle)
            .accessibilityLabel(title)
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .sensoryFeedback(.selection, trigger: isOn)

            Text(title)
                .font(.caption)
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .accessibilityHidden(true)
        }
    }

    private var statusText: String {
        if externalDisplayAvailable {
            if isMuted {
                return NSLocalizedString("The display is muted and shows a black screen.", comment: "Fullscreen Camera: status while a connected display is muted")
            }
            if isFrozen {
                return NSLocalizedString("The display shows the frozen picture.", comment: "Fullscreen Camera: status while the picture on a connected display is frozen")
            }
            return NSLocalizedString("Showing the camera on the connected display.", comment: "Fullscreen Camera: status while a connected display shows the camera")
        }
        if #available(iOS 27.0, *) {
            return NSLocalizedString("Connect a display with AirPlay or a cable to show the camera on it.", comment: "Fullscreen Camera: hint while no display is connected")
        }
        return NSLocalizedString("Mirror your screen with AirPlay or a cable, then tap the picture to hide the controls.", comment: "Fullscreen Camera: hint on iOS versions that can only mirror the screen to a display")
    }
}

/// The camera picture, aspect fit so nothing of what the camera sees is cut off.
private struct CameraPicture: View {
    let feed: CameraFeed
    let isDemo: Bool
    /// Whether the picture stops while the camera is frozen.
    let followsFreeze: Bool

    var body: some View {
        if isDemo {
            DemoPicture()
                .scaleEffect(feed.zoom)
                .clipped()
        } else {
            SampleBufferView(feed: feed, followsFreeze: followsFreeze)
        }
    }
}

/// Shows the camera's frames in an `AVSampleBufferDisplayLayer`, which, unlike a preview layer, can be fed the same frames as other displays and simply keeps the last one when frozen.
private struct SampleBufferView: UIViewRepresentable {
    let feed: CameraFeed
    let followsFreeze: Bool

    final class DisplayView: UIView {
        override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
        var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
    }

    func makeUIView(context: Context) -> DisplayView {
        let view = DisplayView()
        view.backgroundColor = .black
        view.displayLayer.videoGravity = .resizeAspect
        feed.add(view.displayLayer.sampleBufferRenderer, followsFreeze: followsFreeze)
        return view
    }

    func updateUIView(_ view: DisplayView, context: Context) {
        feed.add(view.displayLayer.sampleBufferRenderer, followsFreeze: followsFreeze)
    }

    static func dismantleUIView(_ view: DisplayView, coordinator: ()) {
        // The feed only holds renderers weakly and drops them once their layer is gone.
        view.displayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true)
    }
}

/// Captures the camera and hands every frame to the registered renderers; frozen renderers keep their last frame.
/// On the back it uses the virtual camera made of all lenses, which switches lenses by itself while zooming (and for close-ups).
@Observable
final class CameraFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    @ObservationIgnored private let session = AVCaptureSession()
    @ObservationIgnored private let queue = DispatchQueue(label: "Fullscreen Camera")
    @ObservationIgnored private let output = AVCaptureVideoDataOutput()
    @ObservationIgnored private var input: AVCaptureDeviceInput?
    @ObservationIgnored private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    @ObservationIgnored private var rotationObservation: NSKeyValueObservation?
    @ObservationIgnored private var isConfigured = false

    // Only touched on `queue`.
    @ObservationIgnored private var renderers: [(renderer: WeakRenderer, followsFreeze: Bool)] = []
    @ObservationIgnored private var isFrozen = false
    @ObservationIgnored private var lastFrame: CMSampleBuffer?

    // Only touched on the main thread. Zoom is counted like in the Camera app: 1 is the main lens, 0.5 the ultra wide one.
    private(set) var zoom: CGFloat = 1
    private(set) var zoomRange: ClosedRange<CGFloat> = 1...1
    /// The zoom of each lens, plus the main lens' 2× crop when there's no lens for it, for the lens buttons.
    private(set) var lensZooms: [CGFloat] = []
    /// The device's `videoZoomFactor` times this is `zoom`.
    @ObservationIgnored private var zoomMultiplier: CGFloat = 1

    private struct WeakRenderer {
        weak var renderer: AVSampleBufferVideoRenderer?
    }

    enum StartResult {
        case running
        case accessDenied
        /// Access is allowed, but the session didn't start (e.g. the camera is in use or unavailable).
        case failed
    }

    /// Starts the camera, asking for camera access if needed.
    func start() async -> StartResult {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return .accessDenied }
        return await withCheckedContinuation { continuation in
            queue.async {
                self.configureIfNeeded()
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume(returning: self.session.isRunning ? .running : .failed)
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// Adds a renderer, or updates whether it follows the freeze.
    func add(_ renderer: AVSampleBufferVideoRenderer, followsFreeze: Bool) {
        queue.async {
            self.renderers.removeAll { $0.renderer.renderer == nil || $0.renderer.renderer === renderer }
            self.renderers.append((WeakRenderer(renderer: renderer), followsFreeze))
            // A display that starts following a frozen picture shows that picture, not its last live frame.
            if followsFreeze && self.isFrozen, let frame = self.lastFrame {
                self.enqueue(frame, into: renderer)
            }
        }
    }

    func setFrozen(_ frozen: Bool) {
        queue.async {
            self.isFrozen = frozen
        }
    }

    /// Switches between the back and the front camera.
    func switchCamera() {
        lensZooms = []
        queue.async {
            let position: AVCaptureDevice.Position = self.input?.device.position == .front ? .back : .front
            self.useCamera(at: position)
        }
    }

    /// Zooms to `zoom` (1 is the main lens); `animated` glides there like the Camera app's lens buttons.
    func setZoom(_ zoom: CGFloat, animated: Bool = false) {
        self.zoom = min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
        let factor = self.zoom / zoomMultiplier
        queue.async {
            guard let device = self.input?.device, (try? device.lockForConfiguration()) != nil else { return }
            let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            if animated {
                device.ramp(toVideoZoomFactor: clamped, withRate: 32)
            } else {
                device.cancelVideoZoomRamp()
                device.videoZoomFactor = clamped
            }
            device.unlockForConfiguration()
        }
    }

    /// Lens buttons for the photo in the simulator, which zooms by scaling.
    func useDemoLenses() {
        zoomRange = 0.5...10
        lensZooms = [0.5, 1, 2]
        zoom = 1
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        session.beginConfiguration()
        session.sessionPreset = .high
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        useCamera(at: .back)
    }

    private func useCamera(at position: AVCaptureDevice.Position) {
        // The first of these the device has is the one with the most lenses.
        let deviceTypes: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInWideAngleCamera]
        guard let device = deviceTypes.lazy.compactMap({ AVCaptureDevice.default($0, for: .video, position: position) }).first ?? AVCaptureDevice.default(for: .video),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        if let input {
            session.removeInput(input)
        }
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            input = newInput
        } else if let input, session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
        startAtMainLens()

        // Turn the frames upright, so the picture on the display matches how the phone is held.
        let coordinator = AVCaptureDevice.RotationCoordinator(device: input?.device ?? device, previewLayer: nil)
        rotationCoordinator = coordinator
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            self?.queue.async {
                guard let connection = self?.output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) else { return }
                connection.videoRotationAngle = angle
            }
        }
    }

    /// Starts at 1× (not at the ultra wide lens, where a virtual camera starts) and tells the lens buttons which lenses there are.
    private func startAtMainLens() {
        guard let device = input?.device else { return }
        let multiplier = device.displayVideoZoomFactorMultiplier
        var lenses = ([device.minAvailableVideoZoomFactor] + device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) })
            .map { ($0 * multiplier * 10).rounded() / 10 }
        let maxZoom = min(device.maxAvailableVideoZoomFactor * multiplier, max(10, (lenses.last ?? 1) * 3))
        // Like the Camera app, offer 2× between the main lens and a telephoto lens that zooms further (or none).
        if lenses.contains(1), !lenses.contains(where: { $0 > 1 && $0 <= 2.5 }), maxZoom >= 2 {
            lenses.append(2)
            lenses.sort()
        }

        if (try? device.lockForConfiguration()) != nil {
            device.videoZoomFactor = min(max(1 / multiplier, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.unlockForConfiguration()
        }
        let minZoom = device.minAvailableVideoZoomFactor * multiplier
        DispatchQueue.main.async {
            self.zoomMultiplier = multiplier
            self.zoomRange = minZoom...max(minZoom, maxZoom)
            self.lensZooms = lenses
            self.zoom = max(1, minZoom)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Without a timebase the layer would wait for the frame's time; show it right away.
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true), CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }

        // The frame shown when freezing is kept, so displays that join later show it too.
        if !isFrozen {
            lastFrame = sampleBuffer
        }
        renderers.removeAll { $0.renderer.renderer == nil }
        for entry in renderers where !(entry.followsFreeze && isFrozen) {
            if let renderer = entry.renderer.renderer {
                enqueue(sampleBuffer, into: renderer)
            }
        }
    }

    private func enqueue(_ sampleBuffer: CMSampleBuffer, into renderer: AVSampleBufferVideoRenderer) {
        if renderer.status == .failed {
            renderer.flush()
        }
        if renderer.isReadyForMoreMediaData {
            renderer.enqueue(sampleBuffer)
        }
    }
}

extension View {
    /// Shows `content` on a connected display (AirPlay, monitor) whenever the system offers one; `isAvailable` reports whether it does.
    /// Before iOS 27 the system can only mirror the screen, so nothing is shown then.
    @ViewBuilder
    func externalDisplayPicture<Content: View>(
        isAvailable: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if #available(iOS 27.0, *) {
            self.sceneAccessory {
                ExternalNonInteractiveAccessory(isEnabled: .constant(true)) {
                    content()
                }
                .onAvailabilityChange { available in
                    isAvailable.wrappedValue = available
                }
            }
        } else {
            self
        }
    }
}

/// A stand-in for the camera picture in the simulator: a photo of an open book on a table, as a document camera would see it.
/// "Sea wave book photograph" by Andrew Neel, CC0, https://commons.wikimedia.org/wiki/File:Sea_wave_book_photograph_(Unsplash).jpg
private struct DemoPicture: View {
    var body: some View {
        Image("Fullscreen Camera Demo")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        FullscreenCamera()
    }
}
