//
//  Counter.swift
//  Toolbox
//
//  Created by Christian Nagel on 28.03.22.
//

import SwiftUI
import Haptica

extension UserDefaults {
    
    func valueExists(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }
    
}

struct Counter: View {
    let defaults = UserDefaults.standard
    @State var count = 0
    @State var showAlert = false
    
    var body: some View {
        VStack{
            Spacer()
            Text(String(count))
                .dynamicTypeSize(.accessibility5)
            Spacer()
            HStack{
                Button("-"){
                    print("-")
                    count -= 1
                    defaults.set(count, forKey: "count")
                    Haptic.impact(.light).generate()
                }
                .dynamicTypeSize(.accessibility3)
                .tint(.primary)
                .padding()

                Button("Reset"){
                    print("Reset")
                    showAlert = true
                    Haptic.impact(.rigid).generate()
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Reset Counter"),
                        message: Text("Are you sure, you want to reset the counter?"),
                        primaryButton: .default(
                            Text("Don't Reset"),
                            action: {
                                showAlert = false
                            }
                        ),
                        secondaryButton: .destructive(
                            Text("Reset"),
                            action: {
                                count = 0
                                defaults.set(count, forKey: "count")
                                showAlert = false
                                Haptic.impact(.medium).generate()
                            }
                        )
                    )
                }
                .dynamicTypeSize(.accessibility3)
                .tint(.primary)
                
                Button("+"){
                    print("+")
                    count += 1
                    defaults.set(count, forKey: "count")
                    Haptic.impact(.light).generate()
                }
                .padding()
                .dynamicTypeSize(.accessibility3)
                .tint(.primary)
            }
            Spacer()
        }
        .onAppear(){
            if(defaults.valueExists(forKey: "count")){
                count = defaults.integer(forKey: "count")
            }
        }
        .navigationBarTitleDisplayMode(/*@START_MENU_TOKEN@*/.inline/*@END_MENU_TOKEN@*/)
        .navigationTitle("Counter")
        
    }
    
}

struct Counter_Previews: PreviewProvider {
    static var previews: some View {
        Counter()
    }
}
