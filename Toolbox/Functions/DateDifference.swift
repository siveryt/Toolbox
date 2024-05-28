import SwiftUI
import Foundation
import Haptica
import ToastSwiftUI

struct DateDifference: View{
    func removeTimeFromDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? Date()
    }
    func calcDiff(from start: Date, to end: Date) -> (years: Int, months: Int, days: Int) {
        let calendar = Calendar.current
        
        print("Start: \(start); End: \(end)")
        let startDate = removeTimeFromDate(min(start, end))
        let endDate = removeTimeFromDate(max(start, end))
        print("Start: \(startDate); End: \(endDate)")
        print("-------------------------------------------------------------")
        
        var elements: Set<Calendar.Component> = []
        if(displayDays) {
            elements.insert(Calendar.Component.day)
        }
        if(displayYears) {
            elements.insert(Calendar.Component.year)
        }
        if(displayMonths) {
            elements.insert(Calendar.Component.month)
        }
        
        let components = calendar.dateComponents(elements, from: startDate, to: endDate)
        
        return (years: components.year ?? 0, months: components.month ?? 0, days: components.day ?? 0)
    }
        
    @State private var dateFrom = Date()
    @State private var dateTo = Date()
    @AppStorage("dateDiffYears") var displayYears = true
    @AppStorage("dateDiffMonths") var displayMonths = true
    @AppStorage("dateDiffDays") var displayDays = true
    @State var isPresentingToast: Bool = false
    
    func presentToast() {
        withAnimation {
            isPresentingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isPresentingToast = false
            }
        }
    }
    

    
    
    var body: some View{
        
        Form{
            DatePicker(
                "Start Date",
                selection: $dateFrom,
                displayedComponents: [.date]
            )
            .datePickerStyle(.automatic)
            
            DatePicker(
                "End Date",
                selection: $dateTo,
                displayedComponents: [.date]
            )
            .datePickerStyle(.automatic)
            
            Section {
                DisclosureGroup("Display") {
                    Toggle(isOn: $displayDays) {
                        Text("Days")
                    }
                    .disabled(!displayYears && !displayMonths)
                    
                    Toggle(isOn: $displayMonths) {
                        Text("Months")
                    }
                    .disabled(!displayDays && !displayYears)

                    Toggle(isOn: $displayYears) {
                        Text("Years")
                    }
                    .disabled(!displayDays && !displayMonths)
                }
            }

            Section("Difference") {
                
                if displayDays {
                    KeyValueProperty(content: String(calcDiff(from: dateFrom, to: dateTo).days), propertyName: NSLocalizedString("Days", comment: "Date difference"))
                }
                
                if displayMonths {
                    KeyValueProperty(content: String(calcDiff(from: dateFrom, to: dateTo).months), propertyName: NSLocalizedString("Months", comment: "Date difference"))
                }
                
                if displayYears {
                    KeyValueProperty(content: String(calcDiff(from: dateFrom, to: dateTo).years), propertyName: NSLocalizedString("Years", comment: "Date difference"))
                }
            }.transition(.slide)
            
        }
        
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Date Difference")
    }
}
