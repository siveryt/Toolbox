//
//  FaceCountAppEnum.swift
//  diceWidgetExtension
//
//  Created by Christian Nagel on 09.03.24.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum FaceCountAppEnum: String, AppEnum {
    case four
    case six
    case eight
    case ten
    case twelve
    case twenty

    var imagePrefix: String {
        switch self{
        case .four: return "4-"
        case .six: return "6-"
        case .eight: return "8-"
        case .ten: return "8-"
        case .twelve: return "12-"
        case .twenty: return "8-"
        }
    }
    
    var maxDieSize: Int {
        switch self {
        case .four: return 4
        case .six: return 6
        case .eight: return 8
        case .ten: return 10
        case .twelve: return 12
        case .twenty: return 20
        }
    }
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Face Count")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .four: "4",
        .six: "6",
        .eight: "8",
        .ten: "10",
        .twelve: "12",
        .twenty: "20"
    ]
}

