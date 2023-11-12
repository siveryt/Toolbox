import SwiftUI
import Haptica
import ToastSwiftUI

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
    
    func calcDiff() {
        let calendar = Calendar.current

        // Initialize an empty array to store the components based on user preferences
        var dateComponentsArray: [Calendar.Component] = []

        if displayYears {
            dateComponentsArray.append(.year)
        }

        if displayMonths {
            dateComponentsArray.append(.month)
        }

        if displayDays {
            dateComponentsArray.append(.day)
        }

        // Calculate the difference between two dates with the dynamically created dateComponents array
        let components = calendar.dateComponents(Set(dateComponentsArray), from: dateFrom, to: dateTo)

        // Set global variables based on user preferences
        if displayYears {
            years = "\(abs(components.year ?? 0))"
        }

        if displayMonths {
            months = "\(abs(components.month ?? 0))"
        }

        if displayDays {
            days = "\(abs(components.day ?? 0))"
        }
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
                calcDiff()
            }
            if(defaults.valueExists(forKey: "dateTo")){
                dateTo = defaults.object(forKey: "dateTo") as! Date
                calcDiff()
            }
            
        }
    }
}
