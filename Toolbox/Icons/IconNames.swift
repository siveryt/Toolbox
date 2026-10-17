//
//  IconNames.swift
//  Toolbox
//
//  Created by Christian Nagel on 20.05.22.
//

import Foundation
import UIKit

class IconNames: ObservableObject {
    /// nil is the primary icon (Toolbox.icon), the others are the alternate .icon files
    /// listed in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
    let iconNames: [String?] = [nil, "Toolbox Blue", "Toolbox Green", "Toolbox Lime", "Toolbox Pink", "Toolbox Purple"]
    //exact index we're at inside our icon names
    @Published var currentIndex = 0

    /// Alternate icons of the old PNG icon set and the new icon that replaces them.
    private static let replacedIcons: [String: String?] = [
        "blue": "Toolbox Blue",
        "green": "Toolbox Green",
        "pink": "Toolbox Pink",
        "purple": "Toolbox Purple",
    ]

    init() {
        if let currentIcon = UIApplication.shared.alternateIconName{
            self.currentIndex = iconNames.firstIndex(of: currentIcon) ?? 0
        }
    }

    /// Image shown in the icon picker, rendered from the .icon file by export-previews.sh.
    func previewName(_ index: Int) -> String {
        "Preview " + (iconNames[index] ?? "Toolbox")
    }

    /// Moves users who picked one of the removed PNG icons to its new counterpart, or to the primary icon.
    @MainActor
    static func migrateRemovedIcon() {
        guard let currentIcon = UIApplication.shared.alternateIconName,
              !IconNames().iconNames.contains(currentIcon) else { return }
        UIApplication.shared.setAlternateIconName(replacedIcons[currentIcon] ?? nil)
    }
}
