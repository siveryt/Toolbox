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
        SimpleEntry(date: Date(), configuration: Faces(), number: Int.random(in: 1...4))
    }

    func snapshot(for configuration: Faces, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, number: Int.random(in: 1...4))
    }
    
    func timeline(for configuration: Faces, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        entries = [SimpleEntry(date: Date(), configuration: configuration, number: Int.random(in: 1...(configuration.Faces?.maxDieSize ?? 4)))]

        return Timeline(entries: entries, policy: .never)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: Faces
    let number: Int
}

struct diceWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        
        Button(intent: RollDiceIntent()) {
            VStack {
                Spacer()
                
                HStack {
                    
                    Spacer()
                    Image((entry.configuration.Faces?.imagePrefix ?? FaceCountAppEnum.twenty.imagePrefix) + "\(Int.random(in: 1...(entry.configuration.Faces?.maxDieSize ?? 4)))")
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Spacer()
                }
                Spacer()
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
