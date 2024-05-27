import SwiftUI
import Foundation
import Haptica
import ToastSwiftUI

struct DateDifference: View{
    
    func calcDiff(from startDate: Date, to endDate: Date) {
        
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
        
        let calendar = Calendar.current
        
        
        
        // Define which components are needed
        var components = calendar.dateComponents(elements, from: startDate, to: endDate)

        // Extract values
        var diffYears = components.year ?? 0
        var diffMonths = components.month ?? 0
        var diffDays = components.day ?? 0
        
        diffYears = diffYears < 0 ? abs(diffYears)+1 : diffYears
        diffMonths = diffMonths < 0 ? abs(diffMonths)+1 : diffMonths
        diffDays = diffDays < 0 ? abs(diffDays)+1 : diffDays
        
        years = String(diffYears)
        months = String(diffMonths)
        days = String(diffDays)

        
        
    }
    
    let defaults = UserDefaults.standard
    
    @State private var dateFrom = Date()
    @State private var dateTo = Date()
    @State var days = "0"
    @State var months = "0"
    @State var years = "0"
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
        let dateFromBinding = Binding<Date>(get: {
            self.dateFrom
        }, set: {
            self.dateFrom = $0
            defaults.set(dateFrom, forKey: "dateFrom")
            calcDiff(from: dateFrom, to: dateTo)
        })
        let dateToBinding = Binding<Date>(get: {
            self.dateTo
        }, set: {
            self.dateTo = $0
            defaults.set(dateTo, forKey: "dateFrom")
            calcDiff(from: dateFrom, to: dateTo)
        })
        
        
        let displayDaysBinding = Binding<Bool>(get: {
            self.displayDays
        }, set: {
            self.displayDays = $0
            calcDiff(from: dateFrom, to: dateTo)
        })
        let displayYearsBinding = Binding<Bool>(get: {
            self.displayYears
        }, set: {
            self.displayYears = $0
            calcDiff(from: dateFrom, to: dateTo)
        })
        let displayMonthsBinding = Binding<Bool>(get: {
            self.displayMonths
        }, set: {
            self.displayMonths = $0
            calcDiff(from: dateFrom, to: dateTo)
        })
        
        Form{
            DatePicker(
                "Start Date",
                selection: dateFromBinding,
                displayedComponents: [.date]
            )
            .datePickerStyle(.automatic)
            
            DatePicker(
                "End Date",
                selection: dateToBinding,
                displayedComponents: [.date]
            )
            .datePickerStyle(.automatic)
            
            Section {
                DisclosureGroup("Display") {
                    
                    Toggle(isOn: displayYearsBinding) {
                        Text("Years")
                    }
                    .disabled(!displayDays && !displayMonths)

                    
                    Toggle(isOn: displayMonthsBinding) {
                        Text("Months")
                    }
                    .disabled(!displayDays && !displayYears)

                    
                    Toggle(isOn: displayDaysBinding) {
                        Text("Days")
                    }
                    .disabled(!displayYears && !displayMonths)

                }
            }

            Section("Difference") {
                
                if displayDays {
                    KeyValueProperty(content: days, propertyName: NSLocalizedString("Days", comment: "Date difference"))
                }
                
                if displayMonths {
                    KeyValueProperty(content: months, propertyName: NSLocalizedString("Months", comment: "Date difference"))
                }
                
                if displayYears {
                    KeyValueProperty(content: years, propertyName: NSLocalizedString("Years", comment: "Date difference"))
                }
            }.transition(.slide)
            
        }
        
        .toast(isPresenting: $isPresentingToast, message: NSLocalizedString("Copied", comment: "Copy toast"), icon: .custom(Image(systemName: "doc.on.clipboard")), autoDismiss: .none)
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Date Difference")
        .onAppear(){
            if(defaults.valueExists(forKey: "dateFrom")){
                dateFrom = defaults.object(forKey: "dateFrom") as! Date
                calcDiff(from: dateFrom, to: dateTo)
            }
            if(defaults.valueExists(forKey: "dateTo")){
                dateTo = defaults.object(forKey: "dateTo") as! Date
                calcDiff(from: dateFrom, to: dateTo)
            }
            
        }
    }
}
