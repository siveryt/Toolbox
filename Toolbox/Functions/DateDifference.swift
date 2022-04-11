import SwiftUI

struct DateDifference: View{
    let defaults = UserDefaults.standard
    
    @State private var dateFrom = Date()
    @State private var dateTo = Date()
    @State var result = "0"
    func calcDiff (){
        
        let date1 = dateFrom
        let date2 = dateTo
        let calendar = Calendar.current
        
        let diff = calendar.dateComponents([.year, .month, .day], from: date1, to: date2)
        
        var temp = "\(String(describing: diff.day))"
        let RESULTday = temp.replacingOccurrences(of: "Optional(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "-", with: "")
        temp = "\(String(describing: diff.month))"
        let RESULTmonth = temp.replacingOccurrences(of: "Optional(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "-", with: "")
        temp = "\(String(describing: diff.year))"
        let RESULTyear = temp.replacingOccurrences(of: "Optional(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "-", with: "")
        
        result = ""
        result += RESULTyear != "0" ? NSLocalizedString("Years: ", comment: "Years: -- Number of Years; IMPORTANT: Keep the Colon and the Space after it") + String(RESULTyear) : ""
        result += result == "" ? "" : ", "
        result += RESULTmonth != "0" ? NSLocalizedString("Months: ", comment: "Months: -- Number of Years; IMPORTANT: Keep the Colon and the Space after it") + String(RESULTmonth) : ""
        result += result == "" ? "" : ", "
        result += RESULTday != "0" ? NSLocalizedString("Days: ", comment: "Days: -- Number of Days; IMPORTANT: Keep the Colon and the Space after it") + String(RESULTmonth) : ""
        
        if(result == ""){
            result = "0"
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
            HStack{
                Text("Difference:")
                Spacer()
                Text(result)
            }
            
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
