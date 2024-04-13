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
        SimpleEntry(date: Date(), configuration: Faces(), number: Int.random(in: 1...4), refreshing: false)
    }

    func snapshot(for configuration: Faces, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, number: Int.random(in: 1...4), refreshing: false)
    }
    
    func timeline(for configuration: Faces, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        
        let rolled = Int.random(in: 1...(configuration.Faces?.maxDieSize ?? 4))
        
        entries.append(SimpleEntry(date: Date(), configuration: configuration, number: rolled, refreshing: true))
        entries.append(SimpleEntry(date: Date().addingTimeInterval(TimeInterval(0.2)), configuration: configuration, number: rolled, refreshing: false))
        
        
        //entries = [SimpleEntry(date: Date(), configuration: configuration, number: Int.random(in: 1...(configuration.Faces?.maxDieSize ?? 4)))]

        return Timeline(entries: entries, policy: .never)
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
                        Image((entry.configuration.Faces?.imagePrefix ?? FaceCountAppEnum.twenty.imagePrefix) + "\(entry.number)")
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
        
    }
}

//extension ConfigurationAppIntent {
//    fileprivate static var six: ConfigurationAppIntent {
//        let intent = ConfigurationAppIntent()
//        
//        return intent
//    }
//}

//#Preview(as: .systemSmall) {
//    diceWidget()
//} timeline: {
//    SimpleEntry(date: .now, configuration: .smiley)
//}
