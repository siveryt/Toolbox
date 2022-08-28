import SwiftUI

struct DateDifference: View{
    let defaults = UserDefaults.standard
    
    @State private var dateFrom = Date()
    @State private var dateTo = Date()
    @State var days = "0"
    @State var months = "0"
    @State var years = "0"
    @AppStorage("dateDiffYears") var displayYears = true
    @AppStorage("dateDiffMonths") var displayMonths = true
    @AppStorage("dateDiffDays") var displayDays = true
    
    func calcDiff (){
        
        var components:Set<Calendar.Component> = []
        if displayYears {
            components.insert(.year)
        }
        if displayMonths {
            components.insert(.month)
        }
        if displayDays {
            components.insert(.day)
        }
        
        let calendar = Calendar.current
        let diff = calendar.dateComponents(components, from: dateFrom, to: dateTo)
        
        days = "\(abs(diff.day ?? 0))"
        months = "\(abs(diff.month ?? 0))"
        years = "\(abs(diff.year ?? 0))"
        
        
    }
    
    
    var body: some View{
        let dateFromBinding = Binding<Date>(get: {
            self.dateFrom
        }, set: {
            self.dateFrom = $0
            defaults.set(dateFrom, forKey: "dateFrom")
            calcDiff()
        })
        let dateToBinding = Binding<Date>(get: {
            self.dateTo
        }, set: {
            self.dateTo = $0
            defaults.set(dateTo, forKey: "dateFrom")
            calcDiff()
        })
        
        
        let displayDaysBinding = Binding<Bool>(get: {
            self.displayDays
        }, set: {
            self.displayDays = $0
            calcDiff()
        })
        let displayYearsBinding = Binding<Bool>(get: {
            self.displayYears
        }, set: {
            self.displayYears = $0
            calcDiff()
        })
        let displayMonthsBinding = Binding<Bool>(get: {
            self.displayMonths
        }, set: {
            
            self.displayMonths = $0
                
            
            calcDiff()
        })
        
        Form{
            DatePicker(
                "Start Date:",
                selection: dateFromBinding,
                displayedComponents: [.date]
            )
            .datePickerStyle(.automatic)
            
            DatePicker(
                "End Date:",
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
                    HStack{
                        Text("Days:")
                        Spacer()
                        Text(days)
                    }
                }
                
                if displayMonths {
                    HStack{
                        Text("Months:")
                        Spacer()
                        Text(months)
                    }
                }
                if displayYears {
                    HStack{
                        Text("Years:")
                        Spacer()
                        Text(years)
                    }
                }
            }.transition(.slide)
            
        }
        
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Date Difference")
        .onAppear(){
            if(defaults.valueExists(forKey: "dateFrom")){
                dateFrom = defaults.object(forKey: "dateFrom") as! Date
                calcDiff()
            }
            if(defaults.valueExists(forKey: "dateTo")){
                dateTo = defaults.object(forKey: "dateTo") as! Date
                calcDiff()
            }
            
        }
    }
}
