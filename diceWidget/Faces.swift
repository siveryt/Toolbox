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
    static var description = IntentDescription(LocalizedStringResource("Choose which die the widget rolls.", comment: "Dice widget: description of the widget's configuration"))

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
        IntentPrediction(parameters: (\.$Faces, \.$reroll)) { faces, _ in
            DisplayRepresentation(
                title: LocalizedStringResource("\((faces ?? .six).maxDieSize)-sided die", comment: "Dice widget: suggested widget configuration, e.g. \"6-sided die\"")
            )
        }
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
