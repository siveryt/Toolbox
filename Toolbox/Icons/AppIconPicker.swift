//
//  AppIconPicker.swift
//  Toolbox
//

import SwiftUI
import CoreMotion

/// Settings page to pick the app icon: a carousel of live icons that catch the light when
/// the device tilts, and a Home Screen preview of the icon in focus.
struct appIcon: View {
    @EnvironmentObject var iconSettings: IconNames
    @StateObject private var motion = TiltMotion()
    @State private var focused: String?

    private var focusedIcon: AppIconOption {
        IconNames.all.first { $0.id == focused } ?? iconSettings.currentIcon
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                carousel

                VStack(spacing: 12) {
                    Text(focusedIcon.title)
                        .font(.title2.bold())
                        .contentTransition(.opacity)
                    pageDots
                }

                selectButton

                HomeScreenPreview(icon: focusedIcon, tilt: motion.tilt)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Text(NSLocalizedString("Tilt your iPhone to see the light play on the glass.", comment: "App icon picker hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: focused)
        .onAppear {
            if focused == nil { focused = iconSettings.currentIcon.id }
            motion.start()
        }
        .onDisappear { motion.stop() }
    }

    private var carousel: some View {
        GeometryReader { geometry in
            let itemWidth: CGFloat = 220
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(IconNames.all) { icon in
                        LiveAppIcon(icon: icon, size: 180, tilt: icon.id == focused ? motion.tilt : .zero)
                            .shadow(color: .black.opacity(0.2), radius: 16, y: 10)
                            .frame(width: itemWidth, height: geometry.size.height)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.72)
                                    .opacity(phase.isIdentity ? 1 : 0.6)
                                    .rotation3DEffect(.degrees(phase.value * -30), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                            }
                            .onTapGesture { withAnimation(.snappy) { focused = icon.id } }
                            .accessibilityElement()
                            .accessibilityLabel(icon.title)
                            .accessibilityAddTraits(icon.name == iconSettings.current ? .isSelected : [])
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focused, anchor: .center)
            .scrollIndicators(.hidden)
            .safeAreaPadding(.horizontal, max(0, (geometry.size.width - itemWidth) / 2))
        }
        .frame(height: 240)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(IconNames.all) { icon in
                Circle()
                    .fill(icon.id == focusedIcon.id ? Color.primary : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.snappy, value: focused)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var selectButton: some View {
        if focusedIcon.name == iconSettings.current {
            Label(NSLocalizedString("Current Icon", comment: "App icon picker"), systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(height: 50)
        } else {
            Button {
                iconSettings.select(focusedIcon)
            } label: {
                Text(NSLocalizedString("Use This Icon", comment: "App icon picker"))
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .frame(height: 36)
            }
            .buttonStyle(.glassProminent)
            .frame(height: 50)
        }
    }
}

/// An app icon drawn from its exported background and the vector glyph, so the glyph can
/// float above the background and pick up a moving highlight, like Liquid Glass icons do.
struct LiveAppIcon: View {
    let icon: AppIconOption
    let size: CGFloat
    /// Device tilt, -1...1 on both axes.
    var tilt: CGSize = .zero

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        // the glyph SVG has the same canvas as the .icon file, scaled 6.58 × 160 pt onto 1024 pt
        let glyph = Image("Icon Glyph")
            .resizable()
            .frame(width: size * 1.028, height: size * 1.028)
        // where the light hits, moving across the icon as it tilts
        let light = UnitPoint(x: 0.25 - tilt.width * 0.35, y: 0.15 - tilt.height * 0.35)

        ZStack {
            Image(icon.background)
                .resizable()

            ZStack {
                glyph.foregroundStyle(icon.glyph.opacity(0.92))
                // specular band sweeping over the glass
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0.3),
                        .init(color: .white.opacity(0.75), location: 0.5),
                        .init(color: .white.opacity(0), location: 0.7),
                    ],
                    startPoint: UnitPoint(x: light.x - 0.6, y: light.y - 0.6),
                    endPoint: UnitPoint(x: light.x + 0.6, y: light.y + 0.6)
                )
                .mask(glyph)
                .blendMode(.plusLighter)
            }
            .shadow(color: .black.opacity(0.22), radius: size * 0.025,
                    x: -tilt.width * size * 0.03, y: size * 0.02 - tilt.height * size * 0.03)
            // parallax: the glyph sits above the background
            .offset(x: tilt.width * size * 0.035, y: tilt.height * size * 0.035)

            // soft glare and a lit rim on the side facing the light
            RadialGradient(colors: [.white.opacity(0.18), .clear], center: light, startRadius: 0, endRadius: size * 0.8)
                .blendMode(.plusLighter)
            shape
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0), .white.opacity(0), .white.opacity(0.3)],
                                   startPoint: light, endPoint: UnitPoint(x: 1 - light.x, y: 1 - light.y)),
                    lineWidth: max(1, size * 0.012)
                )
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .rotation3DEffect(.degrees(Double(tilt.width) * 12), axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(Double(-tilt.height) * 12), axis: (x: 1, y: 0, z: 0))
        // the icons in their regular look also in dark mode, otherwise every one would show up dark
        .environment(\.colorScheme, .light)
    }
}

/// A slice of a Home Screen with the icon among placeholder apps.
struct HomeScreenPreview: View {
    let icon: AppIconOption
    var tilt: CGSize = .zero
    @Environment(\.colorScheme) private var colorScheme

    private let iconSize: CGFloat = 58
    private let toolboxSlot = 5

    var body: some View {
        VStack(spacing: 0) {
            Grid(horizontalSpacing: 0, verticalSpacing: 18) {
                ForEach(0..<2) { row in
                    GridRow {
                        ForEach(0..<4) { column in
                            let slot = row * 4 + column
                            VStack(spacing: 6) {
                                if slot == toolboxSlot {
                                    LiveAppIcon(icon: icon, size: iconSize, tilt: tilt)
                                        .id(icon.id)
                                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                                    Text(verbatim: "Toolbox")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 2)
                                } else {
                                    placeholder
                                    Capsule()
                                        .fill(.white.opacity(0.45))
                                        .frame(width: 30 + CGFloat(slot % 3) * 6, height: 5)
                                        .padding(.vertical, 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.top, 28)
            .animation(.snappy, value: icon.id)

            Spacer(minLength: 24)

            HStack {
                ForEach(0..<4) { _ in
                    placeholder.frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(10)
        }
        .frame(height: 300)
        .background(wallpaper)
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel(NSLocalizedString("Home Screen preview", comment: "App icon picker"))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: iconSize * 0.225, style: .continuous)
            .fill(.white.opacity(colorScheme == .dark ? 0.16 : 0.32))
            .frame(width: iconSize, height: iconSize)
    }

    private var wallpaper: some View {
        let dark = colorScheme == .dark
        return MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.6, 0.45], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ], colors: dark ? [
            .indigo, .blue, .purple,
            .black, .indigo, .blue,
            .black, .black, .indigo,
        ] : [
            .cyan, .blue, .indigo,
            .mint, .teal, .purple,
            .orange, .pink, .indigo,
        ])
    }
}

/// Publishes how far the device is tilted from the way it is held, -1...1 on both axes.
/// Without motion hardware (Simulator) it sways slowly on its own, and it stays still with Reduce Motion.
final class TiltMotion: ObservableObject {
    @Published private(set) var tilt: CGSize = .zero

    private let manager = CMMotionManager()
    private var reference: CMAcceleration?
    private var timer: Timer?

    func start() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        if manager.isDeviceMotionAvailable {
            guard !manager.isDeviceMotionActive else { return }
            manager.deviceMotionUpdateInterval = 1 / 60
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self, let gravity = motion?.gravity else { return }
                self.update(gravity)
            }
        } else if timer == nil {
            let start = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
                let t = Date().timeIntervalSince(start)
                self?.tilt = CGSize(width: sin(t * 0.9) * 0.6, height: sin(t * 0.6) * 0.4)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        timer?.invalidate()
        timer = nil
        reference = nil
        tilt = .zero
    }

    private func update(_ gravity: CMAcceleration) {
        let held = reference ?? gravity
        // slowly follow the way the phone is held, so only the movement counts
        reference = CMAcceleration(x: held.x + (gravity.x - held.x) * 0.02,
                                   y: held.y + (gravity.y - held.y) * 0.02,
                                   z: held.z + (gravity.z - held.z) * 0.02)
        let target = CGSize(width: clamp((gravity.x - held.x) * 3), height: clamp((held.y - gravity.y) * 3))
        tilt = CGSize(width: tilt.width + (target.width - tilt.width) * 0.25,
                      height: tilt.height + (target.height - tilt.height) * 0.25)
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(-1, value))
    }
}
