//
//  Extensions.swift
//  Toolbox
//
//  Created by Christian Nagel on 05.11.22.
//

import Foundation
import SwiftUI
import AVFoundation

enum Coordinator {
    static func topViewController(_ viewController: UIViewController? = nil) -> UIViewController? {
        let vc = viewController ?? UIApplication.shared.currentUIWindow()?.rootViewController
        if let navigationController = vc as? UINavigationController {
            return topViewController(navigationController.topViewController)
        } else if let tabBarController = vc as? UITabBarController {
            return tabBarController.presentedViewController != nil ? topViewController(tabBarController.presentedViewController) : topViewController(tabBarController.selectedViewController)
            
        } else if let presentedViewController = vc?.presentedViewController {
            return topViewController(presentedViewController)
        }
        return vc
    }
}

class SelectedItemIndex: ObservableObject {
    @Published var index: Int?
}


public extension UIApplication {
    func currentUIWindow() -> UIWindow? {
        let connectedScenes = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
        
        let window = connectedScenes.first?
            .windows
            .first { $0.isKeyWindow }
        
        return window
        
    }
}

extension View {
    
    func shareFromSheet(shareItem: [Any]) {
        
        let activityViewController = UIActivityViewController(activityItems: shareItem, applicationActivities: nil)
        
        let viewController = Coordinator.topViewController()
        activityViewController.popoverPresentationController?.sourceView = viewController?.view
        viewController?.present(activityViewController, animated: true, completion: nil)
    }
    
    func shareFromView(shareItem: [Any]) {
        let shareActivity = UIActivityViewController(activityItems: shareItem, applicationActivities: nil)
        if let vc = UIApplication.shared.currentUIWindow()?.rootViewController{
            shareActivity.popoverPresentationController?.sourceView = vc.view
            //Setup share activity position on screen on bottom center
            shareActivity.popoverPresentationController?.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.maxY, width: 0, height: 0)
            shareActivity.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.down
            vc.present(shareActivity, animated: true, completion: nil)
        }
    }

    /// Keeps the content out of an active fold (e.g. a partially folded iPhone Duo) by placing it in the larger of the two halves.
    func avoidingActiveDivision() -> some View {
        modifier(AvoidActiveDivisionModifier())
    }
}

struct AvoidActiveDivisionModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let rect = usableRect(in: proxy)
            content
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private func usableRect(in proxy: GeometryProxy) -> CGRect {
        let bounds = CGRect(origin: .zero, size: proxy.size)
        guard #available(iOS 27.1, *),
              let division = proxy.reservedRegions(kind: .division).first(where: \.isActive)?.frame,
              division.intersects(bounds)
        else { return bounds }

        let candidates = [
            CGRect(x: bounds.minX, y: bounds.minY, width: division.minX - bounds.minX, height: bounds.height),
            CGRect(x: division.maxX, y: bounds.minY, width: bounds.maxX - division.maxX, height: bounds.height),
            CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: division.minY - bounds.minY),
            CGRect(x: bounds.minX, y: division.maxY, width: bounds.width, height: bounds.maxY - division.maxY),
        ]
        return candidates
            .filter { $0.width > 0 && $0.height > 0 }
            .max { $0.width * $0.height < $1.width * $1.height } ?? bounds
    }
}

struct ShowingSheetKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

struct ShowingIntKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

struct CopyToastKey:  EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

extension EnvironmentValues {
    var showingSheet: Binding<Bool>? {
        get { self[ShowingSheetKey.self] }
        set { self[ShowingSheetKey.self] = newValue }
    }
    var copyToast: Binding<Bool>? {
        get { self[CopyToastKey.self] }
        set { self[CopyToastKey.self] = newValue }
    }
    
    var showingInt: Int? {
        get { self[ShowingIntKey.self] }
        set { self[ShowingIntKey.self] = newValue }
    }
}

extension AVMetadataObject.ObjectType {
    var friendlyName: String {
        switch self {
        case .face:
            return "Face"
        case .catBody:
            return "Cat Body"
        case .dogBody:
            return "Dog Body"
        case .salientObject:
            return "Salient Object"
        case .qr:
            return "QR Code"
        case .pdf417:
            return "PDF417"
        case .aztec:
            return "Aztec"
        case .code39:
            return "Code 39"
        case .code93:
            return "Code 93"
        case .code128:
            return "Code 128"
        case .dataMatrix:
            return "Data Matrix"
        case .interleaved2of5:
            return "Interleaved 2 of 5"
        case .itf14:
            return "ITF-14"
        case .ean13:
            return "EAN-13"
        case .ean8:
            return "EAN-8"
        case .upce:
            return "UPC-E"
        case .code39Mod43:
            return "Code 39 Mod 43"
        default:
            return self.rawValue
        }
    }
}

extension Int: Identifiable {
    public var id: Int { self }
}
