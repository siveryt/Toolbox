//
//  Scrolling Text.swift
//  Toolbox
//
//  Created by Christian Nagel on 19.05.24.
//

import SwiftUI
import MarqueeText
import TipKit
import AVFoundation

/// Hint shown in the scrolling-text full-screen mode explaining how to exit it.
struct ScrollingTextFullscreenTip: Tip {
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

struct Scrolling_Text: View {
    private let fullscreenTip = ScrollingTextFullscreenTip()
    @State var enabled = false
    @State var scrollerActive = false
    @State var rotateAlert = false
    /// Text shown on a connected display (AirPlay, monitor).
    @State var externalDisplayActive = false
    @State var externalDisplayAvailable = false
    /// Text shown on the back display of an unfolded iPhone Duo. The system only offers that display during camera capture,
    /// so a camera session keeps running while this is active.
    @State var backDisplayActive = false
    @State var backDisplayAvailable = false
    @State var hasHinge = false
    @State var isUnfolded = false
    @State var backDisplayCamera = BackDisplayCamera()
    @State var cameraAccessAlert = false
    @State var backDisplayUnavailableAlert = false
    @AppStorage("Scrolling Text-speed") var scrollingSpeed = 1.0
    @AppStorage("Scrolling Text-text") var text = ""
    
    var body: some View {
        
        Form {
            TextField("Scrolling Text", text: $text)
                .onReceive(NotificationCenter.default.publisher(
                    for: UITextField.textDidBeginEditingNotification)) { _ in
                        DispatchQueue.main.async {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                            )
                        }
                    }
            
            Slider(value: $scrollingSpeed, in: 0.1...2.0, step: 0.1)
            
            Section {
                if backDisplayActive {
                    Button("Stop Scrolling on Back Display") {
                        stopBackDisplay()
                    }
                } else if canUseBackDisplay {
                    Button("Start Scrolling on Back Display") {
                        Task { await startBackDisplay() }
                    }
                } else {
                    Button("Start Scrolling"){
                        if(enabled) {
                            scrollerActive = true
                        } else {
                            rotateAlert = true
                        }
                    }
                    .tint(enabled ? .accentColor : .secondary)
                }

                if externalDisplayAvailable {
                    Button(externalDisplayActive ? "Stop Scrolling on External Display" : "Start Scrolling on External Display") {
                        externalDisplayActive.toggle()
                    }
                }
            } footer: {
                if canUseBackDisplay && !backDisplayActive {
                    Text("The back display is only available while the camera is active, so the camera turns on while the text is shown there.")
                }
            }
            
        }
        // Use the available space instead of the device orientation, so this also works on unusual display shapes (e.g. iPhone Duo).
        // Measured on a background that ignores the keyboard, otherwise typing would make a portrait window look wide.
        .background {
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.size.width > proxy.size.height
                } action: { isWide in
                    enabled = isWide
                    scrollerActive = isWide ? scrollerActive : false
                }
        }
        .secondDisplayScroller(
            externalIsActive: $externalDisplayActive,
            externalIsAvailable: $externalDisplayAvailable,
            backIsActive: $backDisplayActive,
            backIsAvailable: $backDisplayAvailable,
            hasHinge: $hasHinge,
            isUnfolded: $isUnfolded
        ) {
            ScrollingTextMarquee(text: text, scrollingSpeed: scrollingSpeed)
        }
        // Folding or rotating the device turns the back display away from the audience.
        .onChange(of: canUseBackDisplay) { _, canUse in
            if !canUse { stopBackDisplay() }
        }
        .onDisappear {
            stopBackDisplay()
            externalDisplayActive = false
        }
        .alert("Info", isPresented: $rotateAlert) {
        } message: {
            Text("You need to rotate your device to enable the scrolling text.")
        }
        .alert("Camera Access Needed", isPresented: $cameraAccessAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The back display is only available while the camera is active. Allow camera access to show the scrolling text there.")
        }
        .alert("Info", isPresented: $backDisplayUnavailableAlert) {
        } message: {
            Text("The back display isn't available right now.")
        }
        .fullScreenCover(isPresented: $scrollerActive) {
                    ScrollingTextMarquee(text: text, scrollingSpeed: scrollingSpeed)
                    .avoidingActiveDivision()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        scrollerActive = false
                        fullscreenTip.invalidate(reason: .actionPerformed)
                    }
                    .overlay(alignment: .top) {
                        TipView(fullscreenTip)
                            .padding()
                    }
        }
        
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Scrolling Text")
    }

    /// In portrait, an unfolded iPhone Duo faces its back display towards the people in front of you.
    private var canUseBackDisplay: Bool {
        hasHinge && isUnfolded && !enabled
    }

    private func startBackDisplay() async {
        guard await backDisplayCamera.start() else {
            cameraAccessAlert = true
            return
        }
        guard canUseBackDisplay else {
            backDisplayCamera.stop()
            return
        }
        backDisplayActive = true

        // The system decides whether it presents the accessory; don't keep the camera running for nothing.
        try? await Task.sleep(for: .seconds(2))
        if backDisplayActive && !backDisplayAvailable {
            stopBackDisplay()
            backDisplayUnavailableAlert = true
        }
    }

    private func stopBackDisplay() {
        backDisplayActive = false
        backDisplayCamera.stop()
    }
}

/// Keeps a minimal camera session running, which is what makes the system offer the iPhone Duo's back display.
final class BackDisplayCamera: @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "Scrolling Text back display camera")
    private var isConfigured = false

    /// Starts the session, asking for camera access if needed. Returns whether the session is running.
    func start() async -> Bool {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        return await withCheckedContinuation { continuation in
            queue.async {
                self.configureIfNeeded()
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume(returning: self.session.isRunning)
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

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        session.beginConfiguration()
        session.sessionPreset = .low
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ?? AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        // Frames are discarded, the output only exists so the capture session is actually active.
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
    }
}

/// The scrolling text itself, filling the available height.
struct ScrollingTextMarquee: View {
    let text: String
    let scrollingSpeed: Double

    var body: some View {
        GeometryReader { geometry in
            MarqueeText(
                text: text,
                font: UIFont.systemFont(ofSize: geometry.size.height),
                leftFade: 0,
                rightFade: 0,
                startDelay: 0,
                duration: Double(text.count)/(2.0 * scrollingSpeed)
            )
            .ignoresSafeArea()
        }
    }
}

extension View {
    /// Shows `content` on a second display while it is active: a connected external display, or the back display of an unfolded iPhone Duo,
    /// which the system only offers during camera capture. The `...IsAvailable` bindings report whether the system currently offers that display,
    /// `hasHinge`/`isUnfolded` report the device's hinge state.
    @ViewBuilder
    func secondDisplayScroller<Content: View>(
        externalIsActive: Binding<Bool>,
        externalIsAvailable: Binding<Bool>,
        backIsActive: Binding<Bool>,
        backIsAvailable: Binding<Bool>,
        hasHinge: Binding<Bool>,
        isUnfolded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if #available(iOS 27.1, *) {
            self
                .sceneAccessory {
                    ExternalNonInteractiveAccessory(isEnabled: externalIsActive) {
                        content()
                            .background(.black)
                            .foregroundStyle(.white)
                    }
                    .onAvailabilityChange { available in
                        externalIsAvailable.wrappedValue = available
                        if !available { externalIsActive.wrappedValue = false }
                    }
                    CameraCaptureAccessory(isEnabled: backIsActive) {
                        content()
                            .background(.black)
                            .foregroundStyle(.white)
                    }
                    .onAvailabilityChange { available in
                        backIsAvailable.wrappedValue = available
                    }
                }
                .onHingeChange { _, context in
                    hasHinge.wrappedValue = context.hinge != nil
                    isUnfolded.wrappedValue = context.hinge?.status == .fullyOpen
                }
        } else {
            self
        }
    }
}

public struct SelectTextOnEditingModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                if let textField = obj.object as? UITextField {
                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                }
            }
    }
}

extension View {

    /// Select all the text in a TextField when starting to edit.
    /// This will not work with multiple TextField's in a single view due to not able to match the selected TextField with underlying UITextField
    public func selectAllTextOnEditing() -> some View {
        modifier(SelectTextOnEditingModifier())
    }
}




#Preview {
    Scrolling_Text()
}
