//
//  Faces.swift
//  diceWidgetExtension
//
//  Created by Christian Nagel on 09.03.24.
//

import Foundation
import AppIntents

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct Faces: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "FacesIntent"

    static var title: LocalizedStringResource = "Faces"
    static var description = IntentDescription("")

    @Parameter(title: "Faces", default: .six)
    var Faces: FaceCountAppEnum?
    
    @Parameter(title: "Reroll Indicator", default: true)
    var reroll: Bool?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$Faces
            \.$reroll
        }
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$Faces, \.$reroll)) { Faces, reroll in
            DisplayRepresentation(
                title: "",
                subtitle: ""
            )
        }
        
    }

    func perform() async throws -> some IntentResult {
        // TODO: Place your refactored intent handler code here.
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
    static func FacesParameterDisambiguationIntro(count: Int, Faces: FaceCountAppEnum) -> Self {
        "There are \(count) options matching ‘\(Faces)’."
    }
    static func FacesParameterConfirmation(Faces: FaceCountAppEnum) -> Self {
        "Just to confirm, you wanted ‘\(Faces)’?"
    }
}

