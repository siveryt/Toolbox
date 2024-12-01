//
//  TapIntent.swift
//  diceWidgetExtension
//
//  Created by Christian Nagel on 09.03.24.
//


import AppIntents
import WidgetKit

struct RollDiceIntent: AppIntent {
    static var title: LocalizedStringResource = "Roll Dice"
    static var description = IntentDescription("Roll a Die")


    init() {}


    func perform() async throws -> some IntentResult {
        
        /*for dqI in 1...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double("0.\(dqI)")!) {
                
                print("REFRESH")
            }
        }*/
        WidgetCenter.shared.reloadTimelines(ofKind: "LocationForecast")
        
        
        return .result()
    }
}
