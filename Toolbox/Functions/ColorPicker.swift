//
//  ColorPicker.swift
//  Toolbox
//
//  Created by Christian Nagel on 10.04.22.
//

import SwiftUI
import PhotosUI
import Haptica
import ToastSwiftUI

// MARK: - Color Picker

struct ColorPickerView: View {
    /// The picked color, saved as a UIColor under this key (the format of earlier versions).
    private static let storageKey = "UserSelectedColor"

    @State private var color: RGBAColor = ColorPickerView.restoreColor()
    /// The text color checked in the last contrast row.
    @AppStorage("colorPickerContrastColor") private var contrastHex = "#767676"

    @State private var codeInput = ""
    @State private var codeInvalid = false
    @FocusState private var codeFieldFocused: Bool

    @State private var photoItem: PhotosPickerItem?
    @State private var photo: PixelImage?
    @State private var loadingPhoto = false
    @State private var photoFailed = false

    @State private var isPresentingToast = false

    private var contrastColor: RGBAColor {
        RGBAColor.parse(contrastHex) ?? RGBAColor(red: 0.463, green: 0.463, blue: 0.463)
    }

    var body: some View {
        Form {
            Section {
                ColorSwatch(color: color)
                    .frame(height: 110)
                    .listRowInsets(EdgeInsets())
                    .accessibilityHidden(true)

                ColorPicker(NSLocalizedString("Choose Color", comment: "Color Picker tool: label of the color well"), selection: Binding(
                    get: { color.color },
                    set: { newValue in
                        color = RGBAColor(newValue)
                        codeInput = ""
                    }
                ), supportsOpacity: true)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack {
                        Label(NSLocalizedString("Pick from Photo", comment: "Color Picker tool: button that opens a photo to pick a color from it with an eyedropper"), systemImage: "eyedropper")
                        Spacer()
                        if loadingPhoto {
                            ProgressView()
                        }
                    }
                }
                .disabled(loadingPhoto)
            }

            Section {
                TextField(NSLocalizedString("e.g. #FF0000 or rgb(255, 0, 0)", comment: "Color Picker tool: placeholder of the field where you type or paste a color code"), text: $codeInput)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($codeFieldFocused)
                    .onChange(of: codeInput) {
                        codeInvalid = false
                        if let parsed = RGBAColor.parse(codeInput) {
                            color = parsed
                        }
                    }
                    .onSubmit {
                        codeInvalid = !codeInput.trimmingCharacters(in: .whitespaces).isEmpty && RGBAColor.parse(codeInput) == nil
                    }
            } header: {
                Text(NSLocalizedString("Enter a Code", comment: "Color Picker tool: section header of the field where you type or paste a color code"))
            } footer: {
                if codeInvalid {
                    Text(NSLocalizedString("That's not a color code. Try #FF0000, rgb(255, 0, 0), hsl(0, 100%, 50%) or red.", comment: "Color Picker tool: error below the code field when the text can't be read as a color"))
                        .foregroundStyle(.red)
                } else {
                    Text(NSLocalizedString("Type or paste a color as HEX, RGB, HSL, HSB or a CSS color name.", comment: "Color Picker tool: hint below the code field"))
                }
            }

            Section(NSLocalizedString("Colorcodes", comment: "Color Picker tool: section header for HEX/RGB codes")) {
                CodeRow(label: NSLocalizedString("HEX", comment: "Color Picker tool: label for the hexadecimal color code"), value: color.hex, copy: copy)
                CodeRow(label: NSLocalizedString("RGB", comment: "Color Picker tool: label for the color code as red, green, blue values (0–255)"), value: color.rgbString, copy: copy)
                if color.alpha255 < 255 {
                    CodeRow(label: NSLocalizedString("RGBA", comment: "Color Picker tool: label for the color code as red, green, blue (0–255) and opacity (0–1) values"), value: color.rgbaString, copy: copy)
                }
                CodeRow(label: NSLocalizedString("HSL", comment: "Color Picker tool: label for the color code as hue, saturation, lightness"), value: color.hslString, copy: copy)
                CodeRow(label: NSLocalizedString("HSB", comment: "Color Picker tool: label for the color code as hue, saturation, brightness"), value: color.hsbString, copy: copy)
                CodeRow(label: NSLocalizedString("CMYK", comment: "Color Picker tool: label for the color code as cyan, magenta, yellow, key (black) percentages"), value: color.cmykString, copy: copy)
                CodeRow(label: NSLocalizedString("CSS Name", comment: "Color Picker tool: label for the name of the closest CSS named color, like crimson; shown with ≈ when it isn't an exact match"), value: color.cssNameString, copy: { _ in copy(color.nearestCSSName.name) })
            }

            Section {
                ContrastRow(title: NSLocalizedString("White Text", comment: "Color Picker tool: contrast row that checks white text on the picked color"), background: color, text: .white)
                ContrastRow(title: NSLocalizedString("Black Text", comment: "Color Picker tool: contrast row that checks black text on the picked color"), background: color, text: .black)
                ColorPicker(selection: Binding(
                    get: { contrastColor.color },
                    set: { contrastHex = RGBAColor($0).opaque.hex }
                ), supportsOpacity: false) {
                    ContrastRow(title: NSLocalizedString("Text Color", comment: "Color Picker tool: contrast row that checks text in a color of your choice on the picked color; its color well is next to it"), background: color, text: contrastColor)
                }
            } header: {
                Text(NSLocalizedString("Contrast", comment: "Color Picker tool: section header for the WCAG contrast check"))
            } footer: {
                Text(NSLocalizedString("Normal text needs a contrast of 4.5:1 for AA and 7:1 for AAA, large text 3:1 and 4.5:1. Opacity isn't taken into account.", comment: "Color Picker tool: explanation below the contrast check (WCAG levels AA and AAA)"))
            }

            Section(NSLocalizedString("Code", comment: "Color Picker tool: section header for the color as source code (CSS, SwiftUI, UIKit)")) {
                CodeRow(label: "CSS", value: color.cssString, monospaced: true, copy: copy)
                CodeRow(label: "SwiftUI", value: color.swiftUIString, monospaced: true, copy: copy)
                CodeRow(label: "UIKit", value: color.uiKitString, monospaced: true, copy: copy)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .onChange(of: color) {
            saveColor()
        }
        .onChange(of: photoItem) {
            loadPhoto()
        }
        .fullScreenCover(item: $photo) { photo in
            PhotoEyedropper(photo: photo) { picked in
                color = picked
                codeInput = ""
            }
        }
        .alert(NSLocalizedString("Couldn't Open the Photo", comment: "Color Picker tool: alert title when a picked photo can't be loaded"), isPresented: $photoFailed) {
            Button(NSLocalizedString("OK", comment: "The OK button in an alert dialog.")) {}
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(NSLocalizedString("Color Picker", comment: "Menu item"))
    }

    private func copy(_ text: String) {
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

    private func loadPhoto() {
        guard let item = photoItem else { return }
        loadingPhoto = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            // Decoding and redrawing a big photo takes a moment, so not on the main thread
            let loaded = await Task.detached(priority: .userInitiated) {
                data.flatMap { PixelImage(data: $0) }
            }.value
            loadingPhoto = false
            photoItem = nil // so the same photo can be picked again
            if let loaded {
                photo = loaded
            } else {
                photoFailed = true
            }
        }
    }

    /// Loads the last picked color (including its opacity); red if there is none.
    private static func restoreColor() -> RGBAColor {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
            return RGBAColor(red: 1, green: 0, blue: 0)
        }
        return RGBAColor(saved)
    }

    private func saveColor() {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: color.uiColor, requiringSecureCoding: true) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

// MARK: - Rows

/// A color code that is copied when tapped.
private struct CodeRow: View {
    let label: String
    let value: String
    var monospaced = false
    let copy: (String) -> Void

    var body: some View {
        Button {
            copy(value)
        } label: {
            if monospaced {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                    Text(value)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent(label) {
                    Text(value)
                        .monospacedDigit()
                }
            }
        }
        .tint(.primary)
        .accessibilityHint(NSLocalizedString("Copies it to the clipboard", comment: "Color Picker tool: VoiceOver hint of a color code row"))
    }
}

/// Text in `text` on `background` with the WCAG contrast ratio and whether it passes AA and AAA.
private struct ContrastRow: View {
    let title: String
    let background: RGBAColor
    let text: RGBAColor

    private var ratio: Double { background.contrast(with: text) }

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "Aa")
                .font(.title3.bold())
                .foregroundStyle(text.opaque.color)
                .frame(width: 54, height: 38)
                .background(background.opaque.color, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(verbatim: RGBAColor.ratioString(ratio))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            LevelBadge(level: "AA", passed: ratio >= 4.5)
            LevelBadge(level: "AAA", passed: ratio >= 7)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LevelBadge: View {
    let level: String
    let passed: Bool

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: passed ? "checkmark" : "xmark")
            Text(verbatim: level)
        }
        .font(.caption.bold())
        .foregroundStyle(passed ? .green : .red)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background((passed ? Color.green : Color.red).opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: passed
            ? NSLocalizedString("Passes %@", comment: "Color Picker tool: VoiceOver label of a contrast badge; %@ is the WCAG level, AA or AAA")
            : NSLocalizedString("Fails %@", comment: "Color Picker tool: VoiceOver label of a contrast badge; %@ is the WCAG level, AA or AAA"), level))
    }
}

/// The color, on a checkerboard so its opacity shows.
private struct ColorSwatch: View {
    let color: RGBAColor

    var body: some View {
        ZStack {
            if color.alpha255 < 255 {
                Checkerboard()
            }
            Rectangle().fill(color.color)
        }
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 10
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for row in 0..<Int((size.height / cell).rounded(.up)) {
                for column in 0..<Int((size.width / cell).rounded(.up)) where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)), with: .color(Color(white: 0.8)))
                }
            }
        }
    }
}

// MARK: - Photo eyedropper

/// A photo drawn into an sRGB bitmap, so single pixels can be read.
final class PixelImage: Identifiable, @unchecked Sendable {
    let id = UUID()
    /// The photo as drawn, upright and at 1 point per pixel.
    let image: UIImage
    let width: Int
    let height: Int
    /// RGBA, 8 bits each, premultiplied.
    private let pixels: [UInt8]

    /// The long side is scaled down to this, so a 48 MP photo doesn't take hundreds of MB.
    private static let maxSide: CGFloat = 3000

    init?(data: Data) {
        guard let source = UIImage(data: data), source.size.width > 0, source.size.height > 0 else { return nil }
        let factor = min(1, Self.maxSide / max(source.size.width, source.size.height))
        let width = max(1, Int((source.size.width * factor).rounded()))
        let height = max(1, Int((source.size.height * factor).rounded()))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let cgImage: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            // UIKit's draw(in:) applies the photo's orientation; it expects a flipped context
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            UIGraphicsPushContext(context)
            source.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            UIGraphicsPopContext()
            return context.makeImage()
        }
        guard let cgImage else { return nil }
        self.image = UIImage(cgImage: cgImage)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    func color(x: Int, y: Int) -> RGBAColor? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        let index = (y * width + x) * 4
        let alpha = Double(pixels[index + 3]) / 255
        guard alpha > 0 else { return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0) }
        return RGBAColor(
            red: Double(pixels[index]) / 255 / alpha,
            green: Double(pixels[index + 1]) / 255 / alpha,
            blue: Double(pixels[index + 2]) / 255 / alpha,
            alpha: alpha
        )
    }
}

/// Shows a photo with a crosshair and a magnifier; dragging anywhere moves the crosshair (so the finger doesn't cover it), tapping jumps to that spot.
struct PhotoEyedropper: View {
    let photo: PixelImage
    let onPick: (RGBAColor) -> Void

    @Environment(\.dismiss) private var dismiss
    /// The crosshair in pixels of the photo.
    @State private var point: CGPoint
    @State private var dragStart: CGPoint?

    init(photo: PixelImage, onPick: @escaping (RGBAColor) -> Void) {
        self.photo = photo
        self.onPick = onPick
        _point = State(initialValue: CGPoint(x: CGFloat(photo.width) / 2, y: CGFloat(photo.height) / 2))
    }

    private var pixelX: Int { min(photo.width - 1, max(0, Int(point.x))) }
    private var pixelY: Int { min(photo.height - 1, max(0, Int(point.y))) }
    private var picked: RGBAColor { photo.color(x: pixelX, y: pixelY) ?? .black }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let frame = fittedFrame(in: geometry.size)
                let scale = frame.width / CGFloat(photo.width)
                let crosshair = CGPoint(
                    x: frame.minX + (CGFloat(pixelX) + 0.5) * scale,
                    y: frame.minY + (CGFloat(pixelY) + 0.5) * scale
                )
                let loupeSize: CGFloat = 130
                let loupeAbove = crosshair.y - loupeSize / 2 - 30 > loupeSize / 2

                ZStack(alignment: .topLeading) {
                    Image(uiImage: photo.image)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .accessibilityHidden(true)

                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .background(Circle().strokeBorder(.black.opacity(0.6), lineWidth: 4))
                        .frame(width: 22, height: 22)
                        .position(crosshair)

                    Loupe(photo: photo, x: pixelX, y: pixelY)
                        .frame(width: loupeSize, height: loupeSize)
                        .position(x: min(max(crosshair.x, loupeSize / 2 + 8), geometry.size.width - loupeSize / 2 - 8),
                                  y: crosshair.y + (loupeAbove ? -1 : 1) * (loupeSize / 2 + 30))
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let start = dragStart ?? point
                            dragStart = start
                            move(to: CGPoint(x: start.x + value.translation.width / scale, y: start.y + value.translation.height / scale))
                        }
                        .onEnded { value in
                            if abs(value.translation.width) < 4, abs(value.translation.height) < 4 {
                                move(to: CGPoint(x: (value.location.x - frame.minX) / scale, y: (value.location.y - frame.minY) / scale))
                            }
                            dragStart = nil
                        }
                )
            }
            .background(Color(.secondarySystemBackground))
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    ColorSwatch(color: picked)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: picked.hex)
                            .font(.headline.monospaced())
                        Text(NSLocalizedString("Drag to move the crosshair, tap to jump to a spot.", comment: "Color Picker tool: hint in the photo eyedropper"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .background(.bar)
                .accessibilityElement(children: .combine)
            }
            .navigationTitle(NSLocalizedString("Pick from Photo", comment: "Color Picker tool: button that opens a photo to pick a color from it with an eyedropper"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Button that cancels an alert"), role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Use Color", comment: "Color Picker tool: button in the photo eyedropper that takes the color under the crosshair")) {
                        Haptic.impact(.light).generate()
                        onPick(picked)
                        dismiss()
                    }
                }
            }
        }
    }

    private func move(to newPoint: CGPoint) {
        point = CGPoint(
            x: min(max(newPoint.x, 0), CGFloat(photo.width) - 0.01),
            y: min(max(newPoint.y, 0), CGFloat(photo.height) - 0.01)
        )
    }

    /// Where the photo sits when it's scaled to fit.
    private func fittedFrame(in size: CGSize) -> CGRect {
        let scale = min(size.width / CGFloat(photo.width), size.height / CGFloat(photo.height))
        let fitted = CGSize(width: CGFloat(photo.width) * scale, height: CGFloat(photo.height) * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
    }
}

/// The pixels around the crosshair, enlarged, with the picked pixel outlined.
private struct Loupe: View {
    let photo: PixelImage
    let x: Int
    let y: Int
    private let cells = 15

    var body: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(cells)
            for row in 0..<cells {
                for column in 0..<cells {
                    guard let color = photo.color(x: x - cells / 2 + column, y: y - cells / 2 + row) else { continue }
                    context.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)), with: .color(color.color))
                }
            }
            let center = CGRect(x: CGFloat(cells / 2) * cell, y: CGFloat(cells / 2) * cell, width: cell, height: cell)
            context.stroke(Path(center.insetBy(dx: -1, dy: -1)), with: .color(.black), lineWidth: 1)
            context.stroke(Path(center), with: .color(.white), lineWidth: 1.5)
        }
        .background(Color(.systemGray5))
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
        .shadow(radius: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Color model

/// An sRGB color, components in 0...1.
struct RGBAColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let white = RGBAColor(red: 1, green: 1, blue: 1)
    static let black = RGBAColor(red: 0, green: 0, blue: 0)

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    /// Extended-range colors (Display P3 from the color well) are clamped to sRGB.
    init(_ uiColor: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }

    init(_ color: Color) {
        self.init(UIColor(color))
    }

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    private static func clamp(_ value: Double) -> Double {
        value.isNaN ? 0 : min(max(value, 0), 1)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
    var opaque: RGBAColor { RGBAColor(red: red, green: green, blue: blue) }

    // MARK: Components

    private static func to255(_ value: Double) -> Int { Int((value * 255).rounded()) }
    var red255: Int { Self.to255(red) }
    var green255: Int { Self.to255(green) }
    var blue255: Int { Self.to255(blue) }
    var alpha255: Int { Self.to255(alpha) }

    /// Hue in degrees, 0..<360.
    private var hue: Double {
        let maximum = max(red, green, blue), delta = maximum - min(red, green, blue)
        guard delta > 0 else { return 0 }
        let sector: Double
        if maximum == red {
            sector = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maximum == green {
            sector = (blue - red) / delta + 2
        } else {
            sector = (red - green) / delta + 4
        }
        let degrees = sector * 60
        return degrees < 0 ? degrees + 360 : degrees
    }

    var hsl: (hue: Double, saturation: Double, lightness: Double) {
        let maximum = max(red, green, blue), minimum = min(red, green, blue)
        let lightness = (maximum + minimum) / 2
        let delta = maximum - minimum
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
        return (hue, saturation, lightness)
    }

    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let maximum = max(red, green, blue)
        let delta = maximum - min(red, green, blue)
        return (hue, maximum == 0 ? 0 : delta / maximum, maximum)
    }

    var cmyk: (cyan: Double, magenta: Double, yellow: Double, key: Double) {
        let key = 1 - max(red, green, blue)
        guard key < 1 else { return (0, 0, 0, 1) }
        return ((1 - red - key) / (1 - key), (1 - green - key) / (1 - key), (1 - blue - key) / (1 - key), key)
    }

    // MARK: Codes

    /// Codes always use "." (a decimal comma would clash with the separators).
    private static func decimal(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
    private static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    private static func degrees(_ value: Double) -> String { "\(Int(value.rounded()) % 360)°" }

    /// #RRGGBB, or #RRGGBBAA when it isn't opaque.
    var hex: String {
        let rgb = String(format: "#%02X%02X%02X", red255, green255, blue255)
        return alpha255 < 255 ? rgb + String(format: "%02X", alpha255) : rgb
    }
    var rgbString: String { "\(red255), \(green255), \(blue255)" }
    /// "255, 0, 0, 0.5", like CSS rgba().
    var rgbaString: String { rgbString + ", " + Self.decimal(alpha, digits: 2) }
    var hslString: String {
        let hsl = hsl
        return "\(Self.degrees(hsl.hue)), \(Self.percent(hsl.saturation)), \(Self.percent(hsl.lightness))"
    }
    var hsbString: String {
        let hsb = hsb
        return "\(Self.degrees(hsb.hue)), \(Self.percent(hsb.saturation)), \(Self.percent(hsb.brightness))"
    }
    var cmykString: String {
        let cmyk = cmyk
        return [cmyk.cyan, cmyk.magenta, cmyk.yellow, cmyk.key].map(Self.percent).joined(separator: ", ")
    }
    var cssString: String {
        alpha255 < 255 ? "rgba(\(rgbaString))" : "rgb(\(rgbString))"
    }
    /// Components rounded like the HEX code, so both describe the same color.
    private var codeComponents: [String] {
        [red255, green255, blue255].map { Self.decimal(Double($0) / 255, digits: 3) }
    }
    var swiftUIString: String {
        let c = codeComponents
        let opacity = alpha255 < 255 ? ", opacity: \(Self.decimal(alpha, digits: 2))" : ""
        return "Color(red: \(c[0]), green: \(c[1]), blue: \(c[2])\(opacity))"
    }
    var uiKitString: String {
        let c = codeComponents
        return "UIColor(red: \(c[0]), green: \(c[1]), blue: \(c[2]), alpha: \(Self.decimal(alpha, digits: 2)))"
    }

    // MARK: Contrast (WCAG 2)

    private static func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    var relativeLuminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    /// 1...21, ignoring opacity.
    func contrast(with other: RGBAColor) -> Double {
        let a = relativeLuminance, b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// "4.49:1": rounded down, so a ratio just below a threshold never reads as passing.
    static func ratioString(_ ratio: Double) -> String {
        let floored = (ratio * 100).rounded(.down) / 100
        return floored.formatted(.number.precision(.fractionLength(0...2))) + ":1"
    }

    // MARK: CSS names

    var nearestCSSName: (name: String, exact: Bool) {
        let opaque = self.opaque
        let lab = opaque.lab
        var best = Self.cssColors[0], bestDistance = Double.infinity
        for named in Self.cssColors {
            if named.color.hex == opaque.hex { return (named.name, true) }
            let distance = named.lab.distance(to: lab)
            if distance < bestDistance {
                best = named
                bestDistance = distance
            }
        }
        return (best.name, false)
    }

    var cssNameString: String {
        let nearest = nearestCSSName
        return nearest.exact ? nearest.name : "≈ " + nearest.name
    }

    struct Lab {
        let l: Double, a: Double, b: Double
        func distance(to other: Lab) -> Double {
            let dl = l - other.l, da = a - other.a, db = b - other.b
            return (dl * dl + da * da + db * db).squareRoot()
        }
    }

    /// CIELAB (D65), to find the closest name by how different colors look.
    var lab: Lab {
        let r = Self.linear(red), g = Self.linear(green), b = Self.linear(blue)
        let x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
        let y = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
        func f(_ t: Double) -> Double { t > 216.0 / 24389 ? cbrt(t) : (24389.0 / 27 * t + 16) / 116 }
        let fx = f(x), fy = f(y), fz = f(z)
        return Lab(l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    private struct NamedColor {
        let name: String
        let color: RGBAColor
        let lab: Lab
    }

    /// The CSS named colors. Where two names mean the same color, the first one is shown.
    private static let cssColors: [NamedColor] = cssColorTable.map { name, hex in
        let color = RGBAColor(hex: hex)
        return NamedColor(name: name, color: color, lab: color.lab)
    }

    private static let cssColorTable: [(String, UInt32)] = [
        ("aliceblue", 0xF0F8FF), ("antiquewhite", 0xFAEBD7), ("aqua", 0x00FFFF), ("aquamarine", 0x7FFFD4),
        ("azure", 0xF0FFFF), ("beige", 0xF5F5DC), ("bisque", 0xFFE4C4), ("black", 0x000000),
        ("blanchedalmond", 0xFFEBCD), ("blue", 0x0000FF), ("blueviolet", 0x8A2BE2), ("brown", 0xA52A2A),
        ("burlywood", 0xDEB887), ("cadetblue", 0x5F9EA0), ("chartreuse", 0x7FFF00), ("chocolate", 0xD2691E),
        ("coral", 0xFF7F50), ("cornflowerblue", 0x6495ED), ("cornsilk", 0xFFF8DC), ("crimson", 0xDC143C),
        ("cyan", 0x00FFFF), ("darkblue", 0x00008B), ("darkcyan", 0x008B8B), ("darkgoldenrod", 0xB8860B),
        ("darkgray", 0xA9A9A9), ("darkgreen", 0x006400), ("darkgrey", 0xA9A9A9), ("darkkhaki", 0xBDB76B),
        ("darkmagenta", 0x8B008B), ("darkolivegreen", 0x556B2F), ("darkorange", 0xFF8C00), ("darkorchid", 0x9932CC),
        ("darkred", 0x8B0000), ("darksalmon", 0xE9967A), ("darkseagreen", 0x8FBC8F), ("darkslateblue", 0x483D8B),
        ("darkslategray", 0x2F4F4F), ("darkslategrey", 0x2F4F4F), ("darkturquoise", 0x00CED1), ("darkviolet", 0x9400D3),
        ("deeppink", 0xFF1493), ("deepskyblue", 0x00BFFF), ("dimgray", 0x696969), ("dimgrey", 0x696969),
        ("dodgerblue", 0x1E90FF), ("firebrick", 0xB22222), ("floralwhite", 0xFFFAF0), ("forestgreen", 0x228B22),
        ("fuchsia", 0xFF00FF), ("gainsboro", 0xDCDCDC), ("ghostwhite", 0xF8F8FF), ("gold", 0xFFD700),
        ("goldenrod", 0xDAA520), ("gray", 0x808080), ("green", 0x008000), ("greenyellow", 0xADFF2F),
        ("grey", 0x808080), ("honeydew", 0xF0FFF0), ("hotpink", 0xFF69B4), ("indianred", 0xCD5C5C),
        ("indigo", 0x4B0082), ("ivory", 0xFFFFF0), ("khaki", 0xF0E68C), ("lavender", 0xE6E6FA),
        ("lavenderblush", 0xFFF0F5), ("lawngreen", 0x7CFC00), ("lemonchiffon", 0xFFFACD), ("lightblue", 0xADD8E6),
        ("lightcoral", 0xF08080), ("lightcyan", 0xE0FFFF), ("lightgoldenrodyellow", 0xFAFAD2), ("lightgray", 0xD3D3D3),
        ("lightgreen", 0x90EE90), ("lightgrey", 0xD3D3D3), ("lightpink", 0xFFB6C1), ("lightsalmon", 0xFFA07A),
        ("lightseagreen", 0x20B2AA), ("lightskyblue", 0x87CEFA), ("lightslategray", 0x778899), ("lightslategrey", 0x778899),
        ("lightsteelblue", 0xB0C4DE), ("lightyellow", 0xFFFFE0), ("lime", 0x00FF00), ("limegreen", 0x32CD32),
        ("linen", 0xFAF0E6), ("magenta", 0xFF00FF), ("maroon", 0x800000), ("mediumaquamarine", 0x66CDAA),
        ("mediumblue", 0x0000CD), ("mediumorchid", 0xBA55D3), ("mediumpurple", 0x9370DB), ("mediumseagreen", 0x3CB371),
        ("mediumslateblue", 0x7B68EE), ("mediumspringgreen", 0x00FA9A), ("mediumturquoise", 0x48D1CC), ("mediumvioletred", 0xC71585),
        ("midnightblue", 0x191970), ("mintcream", 0xF5FFFA), ("mistyrose", 0xFFE4E1), ("moccasin", 0xFFE4B5),
        ("navajowhite", 0xFFDEAD), ("navy", 0x000080), ("oldlace", 0xFDF5E6), ("olive", 0x808000),
        ("olivedrab", 0x6B8E23), ("orange", 0xFFA500), ("orangered", 0xFF4500), ("orchid", 0xDA70D6),
        ("palegoldenrod", 0xEEE8AA), ("palegreen", 0x98FB98), ("paleturquoise", 0xAFEEEE), ("palevioletred", 0xDB7093),
        ("papayawhip", 0xFFEFD5), ("peachpuff", 0xFFDAB9), ("peru", 0xCD853F), ("pink", 0xFFC0CB),
        ("plum", 0xDDA0DD), ("powderblue", 0xB0E0E6), ("purple", 0x800080), ("rebeccapurple", 0x663399),
        ("red", 0xFF0000), ("rosybrown", 0xBC8F8F), ("royalblue", 0x4169E1), ("saddlebrown", 0x8B4513),
        ("salmon", 0xFA8072), ("sandybrown", 0xF4A460), ("seagreen", 0x2E8B57), ("seashell", 0xFFF5EE),
        ("sienna", 0xA0522D), ("silver", 0xC0C0C0), ("skyblue", 0x87CEEB), ("slateblue", 0x6A5ACD),
        ("slategray", 0x708090), ("slategrey", 0x708090), ("snow", 0xFFFAFA), ("springgreen", 0x00FF7F),
        ("steelblue", 0x4682B4), ("tan", 0xD2B48C), ("teal", 0x008080), ("thistle", 0xD8BFD8),
        ("tomato", 0xFF6347), ("turquoise", 0x40E0D0), ("violet", 0xEE82EE), ("wheat", 0xF5DEB3),
        ("white", 0xFFFFFF), ("whitesmoke", 0xF5F5F5), ("yellow", 0xFFFF00), ("yellowgreen", 0x9ACD32),
    ]

    // MARK: Parsing

    /// Reads HEX (#RGB, #RGBA, #RRGGBB, #RRGGBBAA, with # or 0x or neither), rgb()/rgba(), hsl()/hsla(),
    /// hsb()/hsv(), bare "255, 0, 0" and CSS color names. Separators can be commas, spaces or "/".
    static func parse(_ input: String) -> RGBAColor? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }

        if let named = cssColors.first(where: { $0.name == text }) {
            return named.color
        }
        if text == "transparent" {
            return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        }

        var hex = Substring(text)
        if hex.hasPrefix("#") {
            hex = hex.dropFirst()
        } else if hex.hasPrefix("0x") {
            hex = hex.dropFirst(2)
        }
        if [3, 4, 6, 8].contains(hex.count), hex.allSatisfy(\.isHexDigit) {
            return parseHex(String(hex))
        }

        // name(arguments) or just the arguments
        var name = ""
        var arguments = Substring(text)
        if let open = text.firstIndex(of: "(") {
            name = text[..<open].trimmingCharacters(in: .whitespaces)
            arguments = text[text.index(after: open)...]
            if arguments.hasSuffix(")") {
                arguments = arguments.dropLast()
            }
        }
        let tokens = arguments
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" })
            .map(String.init)
        guard tokens.count == 3 || tokens.count == 4 else { return nil }

        let alpha: Double
        if tokens.count == 4 {
            guard let value = number(tokens[3]) else { return nil }
            alpha = value.percent ? value.value / 100 : value.value
        } else {
            alpha = 1
        }

        switch name {
        case "", "rgb", "rgba":
            var components: [Double] = []
            for token in tokens.prefix(3) {
                guard let value = number(token), !value.degrees else { return nil }
                components.append(value.percent ? value.value / 100 : value.value / 255)
            }
            return RGBAColor(red: components[0], green: components[1], blue: components[2], alpha: alpha)
        case "hsl", "hsla", "hsb", "hsba", "hsv", "hsva":
            guard let hue = number(tokens[0]), !hue.percent,
                  let saturation = number(tokens[1]), !saturation.degrees,
                  let third = number(tokens[2]), !third.degrees else { return nil }
            let s = min(max(saturation.value / 100, 0), 1)
            let t = min(max(third.value / 100, 0), 1)
            return name.hasPrefix("hsl")
                ? fromHSL(hue: hue.value, saturation: s, lightness: t, alpha: alpha)
                : fromHSB(hue: hue.value, saturation: s, brightness: t, alpha: alpha)
        default:
            return nil
        }
    }

    private static func parseHex(_ hex: String) -> RGBAColor? {
        // #RGB(A) doubles every digit
        let digits = hex.count <= 4 ? hex.map { "\($0)\($0)" }.joined() : hex
        guard let value = UInt64(digits, radix: 16) else { return nil }
        let hasAlpha = digits.count == 8
        let rgb = UInt32(hasAlpha ? value >> 8 : value)
        var color = RGBAColor(hex: rgb)
        if hasAlpha {
            color.alpha = Double(value & 0xFF) / 255
        }
        return color
    }

    /// A number with an optional "%" or "°"/"deg".
    private static func number(_ token: String) -> (value: Double, percent: Bool, degrees: Bool)? {
        var text = token
        var percent = false, degrees = false
        if text.hasSuffix("%") {
            percent = true
            text.removeLast()
        } else if text.hasSuffix("°") {
            degrees = true
            text.removeLast()
        } else if text.hasSuffix("deg") {
            degrees = true
            text.removeLast(3)
        }
        guard let value = Double(text), value.isFinite else { return nil }
        return (value, percent, degrees)
    }

    private static func fromHue(_ hue: Double, chroma: Double, match: Double, alpha: Double) -> RGBAColor {
        var h = hue.truncatingRemainder(dividingBy: 360)
        if h < 0 { h += 360 }
        let sector = h / 60
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double)
        switch sector {
        case ..<1: (r, g, b) = (chroma, x, 0)
        case ..<2: (r, g, b) = (x, chroma, 0)
        case ..<3: (r, g, b) = (0, chroma, x)
        case ..<4: (r, g, b) = (0, x, chroma)
        case ..<5: (r, g, b) = (x, 0, chroma)
        default: (r, g, b) = (chroma, 0, x)
        }
        return RGBAColor(red: r + match, green: g + match, blue: b + match, alpha: alpha)
    }

    static func fromHSL(hue: Double, saturation: Double, lightness: Double, alpha: Double = 1) -> RGBAColor {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        return fromHue(hue, chroma: chroma, match: lightness - chroma / 2, alpha: alpha)
    }

    static func fromHSB(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1) -> RGBAColor {
        let chroma = brightness * saturation
        return fromHue(hue, chroma: chroma, match: brightness - chroma, alpha: alpha)
    }
}

struct ColorPicker_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ColorPickerView()
        }
    }
}
