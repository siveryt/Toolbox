//
//  diceWidget.swift
//  diceWidget
//
//  Created by Christian Nagel on 09.03.24.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        let configuration = Faces()
        return SimpleEntry(date: Date(), configuration: configuration, number: roll(configuration), refreshing: false)
    }

    func snapshot(for configuration: Faces, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, number: roll(configuration), refreshing: false)
    }
    
    func timeline(for configuration: Faces, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        
        let rolled = roll(configuration)
        
        entries.append(SimpleEntry(date: Date(), configuration: configuration, number: rolled, refreshing: true))
        entries.append(SimpleEntry(date: Date().addingTimeInterval(TimeInterval(0.2)), configuration: configuration, number: rolled, refreshing: false))

        return Timeline(entries: entries, policy: .never)
    }

    /// A face of the configured die; the same fallback as the image, so the number always has a picture.
    private func roll(_ configuration: Faces) -> Int {
        Int.random(in: 1...(configuration.Faces ?? .six).maxDieSize)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: Faces
    let number: Int
    let refreshing: Bool
}

struct diceWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        
        Button(intent: RollDiceIntent()) {
            VStack {
                if(entry.configuration.reroll ?? true) {   
                    Spacer()
                    if(entry.refreshing) {
                        Text("Rerolling")
                    }
                }
                Spacer(minLength: 0)
                
                HStack {
                    
                    Spacer(minLength: 0)
                    ZStack{
                        Image((entry.configuration.Faces ?? .six).imagePrefix + "\(entry.number)")
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        
    }
}

struct diceWidget: Widget {
    let kind: String = "diceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: Faces.self, provider: Provider()) { entry in
            diceWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                
        }
        .contentMarginsDisabled()
        .configurationDisplayName(NSLocalizedString("Dice", comment: "Menu item"))
        .description(NSLocalizedString("Roll a die right on your Home Screen. Tap it to roll again.", comment: "Dice widget: description in the widget gallery"))
        // A single centered die; it fits the system sizes, but would be lost on an iPad's extra large widget.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
