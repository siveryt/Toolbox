//
//  IconNames.swift
//  Toolbox
//
//  Created by Christian Nagel on 20.05.22.
//

import Foundation
import SwiftUI
import UIKit

/// One of the app icons the user can pick in Settings.
struct AppIconOption: Identifiable {
    /// nil is the primary icon (Toolbox.icon), the others are the alternate .icon files
    /// listed in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
    let name: String?
    let title: String
    /// Color of the tool glyph, matching the .icon file.
    var glyph: Color = .white

    var id: String { name ?? "Toolbox" }
    /// The icon without its glyph, rendered from the .icon file by export-previews.sh.
    var background: String { "Background " + id }
}

@MainActor
class IconNames: ObservableObject {
    static let all: [AppIconOption] = [
        AppIconOption(name: nil, title: NSLocalizedString("Red", comment: "App icon name")),
        AppIconOption(name: "Toolbox Orange", title: NSLocalizedString("Orange", comment: "App icon name")),
        AppIconOption(name: "Toolbox Lime", title: NSLocalizedString("Lime", comment: "App icon name")),
        AppIconOption(name: "Toolbox Green", title: NSLocalizedString("Green", comment: "App icon name")),
        AppIconOption(name: "Toolbox Blue", title: NSLocalizedString("Blue", comment: "App icon name")),
        AppIconOption(name: "Toolbox Purple", title: NSLocalizedString("Purple", comment: "App icon name")),
        AppIconOption(name: "Toolbox Pink", title: NSLocalizedString("Pink", comment: "App icon name")),
        AppIconOption(name: "Toolbox White", title: NSLocalizedString("White", comment: "App icon name"),
                      glyph: Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .white : UIColor(white: 0.11, alpha: 1) })),
        AppIconOption(name: "Toolbox Black", title: NSLocalizedString("Black", comment: "App icon name")),
        AppIconOption(name: "Toolbox Pride", title: NSLocalizedString("Pride", comment: "App icon name")),
    ]

    /// Alternate icon name that is currently set, nil for the primary icon.
    @Published var current: String? = UIApplication.shared.alternateIconName

    var currentIcon: AppIconOption {
        Self.all.first { $0.name == current } ?? Self.all[0]
    }

    /// Alternate icons of the old PNG icon set and the new icon that replaces them.
    private static let replacedIcons: [String: String?] = [
        "black": "Toolbox Black",
        "blue": "Toolbox Blue",
        "green": "Toolbox Green",
        "pink": "Toolbox Pink",
        "purple": "Toolbox Purple",
        "whiteOnly": "Toolbox White",
    ]

    func select(_ icon: AppIconOption) {
        guard icon.name != current else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(icon.name)
                current = icon.name
            } catch {
                // The icon stays as it is; the picker keeps showing the current one
            }
        }
    }

    /// Moves users who picked one of the removed PNG icons to its new counterpart, or to the primary icon.
    static func migrateRemovedIcon() {
        guard let currentIcon = UIApplication.shared.alternateIconName,
              !all.contains(where: { $0.name == currentIcon }) else { return }
        UIApplication.shared.setAlternateIconName(replacedIcons[currentIcon] ?? nil)
    }
}
